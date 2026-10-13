package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.tasks.domain.AssignmentMode;
import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.Rotation;
import com.betterhome.tasks.domain.RoundRobin;
import com.betterhome.tasks.domain.RruleEngine;
import com.betterhome.tasks.domain.SystemActors;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskRecurrence;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.membership.MembershipGateway;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class RecurrenceSpawnService {

    private final MembershipGateway membershipGateway;
    private final OutboxService outboxService;
    private final Clock clock;
    private final EntityManager entityManager;

    @Inject
    public RecurrenceSpawnService(
            MembershipGateway membershipGateway,
            OutboxService outboxService,
            Clock clock,
            EntityManager entityManager) {
        this.membershipGateway = membershipGateway;
        this.outboxService = outboxService;
        this.clock = clock;
        this.entityManager = entityManager;
    }

    /**
     * Claim due recurrences with SKIP LOCKED and spawn. For each claimed row, catch up until {@code
     * next_run_at} is in the future or null (bounded by {@code limit} occurrences total).
     */
    @Transactional
    public int claimAndSpawnDue(int limit) {
        Instant now = clock.now();
        Query query =
                entityManager.createNativeQuery(
                        """
                        SELECT id FROM task_recurrence
                        WHERE next_run_at IS NOT NULL AND next_run_at <= :now
                        ORDER BY next_run_at
                        FOR UPDATE SKIP LOCKED
                        LIMIT :lim
                        """);
        query.setParameter("now", java.sql.Timestamp.from(now));
        query.setParameter("lim", Math.max(limit, 1));
        @SuppressWarnings("unchecked")
        List<?> rawIds = query.getResultList();
        int spawned = 0;
        for (Object rawId : rawIds) {
            UUID id = rawId instanceof UUID u ? u : UUID.fromString(rawId.toString());
            TaskRecurrence recurrence = TaskRecurrence.findOptionalById(id).orElse(null);
            if (recurrence == null) {
                continue;
            }
            while (recurrence.nextRunAt != null
                    && !recurrence.nextRunAt.isAfter(now)
                    && spawned < limit) {
                spawnOne(recurrence, now);
                spawned++;
                entityManager.flush();
            }
        }
        return spawned;
    }

    private void spawnOne(TaskRecurrence recurrence, Instant now) {
        TaskTemplate template =
                TaskTemplate.findInHousehold(recurrence.householdId, recurrence.templateId)
                        .orElse(null);
        if (template == null || template.isArchived()) {
            recurrence.nextRunAt = null;
            recurrence.updatedAt = now;
            return;
        }

        Instant occurrenceAt = recurrence.nextRunAt;
        supersedeOpen(recurrence.householdId, recurrence.templateId, now);

        List<UUID> eligible = membershipGateway.listEligibleAssigneeIds(recurrence.householdId);
        UUID assignee;
        boolean nobodyAvailable = false;
        if (recurrence.assignmentMode == AssignmentMode.fixed) {
            if (eligible.contains(recurrence.fixedAssigneeId)) {
                assignee = recurrence.fixedAssigneeId;
            } else if (!eligible.isEmpty()) {
                Rotation rotation = Rotation.findOptionalById(recurrence.rotationId).orElse(null);
                assignee =
                        RoundRobin.next(
                                        eligible,
                                        rotation == null ? null : rotation.lastAssignedUserId)
                                .orElse(eligible.getFirst());
            } else {
                nobodyAvailable = true;
                assignee = fallbackAssignee(recurrence);
            }
        } else {
            Rotation rotation = Rotation.findOptionalById(recurrence.rotationId).orElse(null);
            assignee =
                    RoundRobin.next(eligible, rotation == null ? null : rotation.lastAssignedUserId)
                            .orElse(null);
            if (assignee == null) {
                nobodyAvailable = true;
                assignee = fallbackAssignee(recurrence);
            }
        }

        Instant dueAt = occurrenceAt.plus(template.defaultDueOffsetMinutes, ChronoUnit.MINUTES);
        Task task = new Task();
        task.id = UUID.randomUUID();
        task.householdId = recurrence.householdId;
        task.templateId = template.id;
        task.origin = TaskOrigin.recurrence;
        task.title = template.title;
        task.emoji = template.emoji;
        task.description = template.description;
        task.points = template.points;
        task.latePoints = template.latePoints;
        task.assigneeId = assignee;
        task.dueAt = dueAt;
        task.createdAt = now;
        task.updatedAt = now;
        if (nobodyAvailable) {
            task.status = TaskStatus.dismissed;
            task.dismissedBy = SystemActors.AUTOMATION;
            task.dismissalReason = DismissalReason.nobody_available;
        } else {
            task.status = TaskStatus.open;
            advanceRotation(recurrence.rotationId, assignee);
            outboxService.enqueue(
                    recurrence.householdId,
                    assignee,
                    "task_assigned",
                    "New chore",
                    template.title,
                    payload(task.id));
        }
        task.persist();

        ZoneId zone = ZoneId.of(recurrence.timezone);
        recurrence.lastGeneratedAt = occurrenceAt;
        recurrence.nextRunAt =
                RruleEngine.nextOccurrence(
                                recurrence.rrule,
                                zone,
                                recurrence.startsAt,
                                recurrence.endsAt,
                                occurrenceAt)
                        .orElse(null);
        recurrence.updatedAt = now;
    }

    private UUID fallbackAssignee(TaskRecurrence recurrence) {
        List<UUID> active = membershipGateway.listActiveMemberIds(recurrence.householdId);
        if (recurrence.fixedAssigneeId != null && active.contains(recurrence.fixedAssigneeId)) {
            return recurrence.fixedAssigneeId;
        }
        if (!active.isEmpty()) {
            return active.getFirst();
        }
        // Household with no members should not have a recurrence; use automation id as last resort
        return SystemActors.AUTOMATION;
    }

    private void supersedeOpen(UUID householdId, UUID templateId, Instant now) {
        for (Task open : Task.listOpenRecurrenceForTemplate(householdId, templateId)) {
            open.status = TaskStatus.dismissed;
            open.dismissedBy = SystemActors.AUTOMATION;
            open.dismissalReason = DismissalReason.superseded;
            open.updatedAt = now;
            outboxService.enqueue(
                    householdId,
                    open.assigneeId,
                    "superseded",
                    "Chore superseded",
                    open.title,
                    payload(open.id));
        }
    }

    private static String payload(UUID taskId) {
        return "{\"taskId\":\"" + taskId + "\"}";
    }

    private void advanceRotation(UUID rotationId, UUID assigneeId) {
        Rotation.findOptionalById(rotationId)
                .ifPresent(rotation -> rotation.lastAssignedUserId = assigneeId);
    }
}
