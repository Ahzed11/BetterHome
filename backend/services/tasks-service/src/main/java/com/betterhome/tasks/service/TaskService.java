package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.RoundRobin;
import com.betterhome.tasks.domain.Rotation;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.ledger.PointsLedgerClient;
import com.betterhome.tasks.membership.MembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class TaskService {

    private final CallerService callerService;
    private final MembershipGateway membershipGateway;
    private final PointsLedgerClient pointsLedgerClient;
    private final Clock clock;

    @Inject
    public TaskService(
            CallerService callerService,
            MembershipGateway membershipGateway,
            PointsLedgerClient pointsLedgerClient,
            Clock clock) {
        this.callerService = callerService;
        this.membershipGateway = membershipGateway;
        this.pointsLedgerClient = pointsLedgerClient;
        this.clock = clock;
    }

    public List<Task> list(UUID householdId, TaskStatus status, boolean mineOnly) {
        MemberView caller = callerService.requireMember(householdId);
        UUID assigneeFilter = mineOnly ? caller.userId() : null;
        return Task.listForHousehold(householdId, status, assigneeFilter);
    }

    @Transactional
    public Task createOpen(UUID householdId, UUID templateId, UUID assigneeId, Instant dueAt) {
        callerService.requireAdmin(householdId);
        TaskTemplate template = requireActiveTemplate(householdId, templateId);
        UUID assignee = resolveAssignee(householdId, template, assigneeId);
        Instant now = clock.now();
        Instant due =
                dueAt != null
                        ? dueAt
                        : now.plus(template.defaultDueOffsetMinutes, ChronoUnit.MINUTES);

        Task task = snapshotTask(householdId, template, TaskOrigin.ad_hoc, assignee, due, now);
        task.status = TaskStatus.open;
        task.persist();
        advanceRotation(template.rotationId, assignee);
        return task;
    }

    @Transactional
    public Task quickLog(UUID householdId, UUID templateId) {
        MemberView caller = callerService.requireMember(householdId);
        TaskTemplate template = requireActiveTemplate(householdId, templateId);
        Instant now = clock.now();

        Task task =
                snapshotTask(householdId, template, TaskOrigin.manual, caller.userId(), null, now);
        task.status = TaskStatus.done;
        task.completerId = caller.userId();
        task.completedAt = now;
        task.pointsAwarded = template.points;
        task.persist();
        pointsLedgerClient.award(
                householdId, caller.userId(), task.id, template.points, false);
        return task;
    }

    @Transactional
    public Task complete(UUID householdId, UUID taskId) {
        MemberView caller = callerService.requireMember(householdId);
        Task task = requireTask(householdId, taskId);
        if (task.status != TaskStatus.open) {
            throw new TaskException.Conflict("Only open tasks can be completed");
        }
        if (!caller.admin() && !task.assigneeId.equals(caller.userId())) {
            throw new TaskException.Forbidden("Only the assignee or an admin can complete");
        }
        Instant now = clock.now();
        boolean late = task.dueAt != null && now.isAfter(task.dueAt);
        task.status = TaskStatus.done;
        task.completerId = caller.userId();
        task.completedAt = now;
        task.pointsAwarded = late ? task.latePoints : task.points;
        task.updatedAt = now;
        pointsLedgerClient.award(
                householdId, task.assigneeId, task.id, task.pointsAwarded, late);
        return task;
    }

    @Transactional
    public Task dismiss(UUID householdId, UUID taskId) {
        MemberView caller = callerService.requireMember(householdId);
        Task task = requireTask(householdId, taskId);
        if (task.status != TaskStatus.open) {
            throw new TaskException.Conflict("Only open tasks can be dismissed");
        }
        if (!caller.admin() && !task.assigneeId.equals(caller.userId())) {
            throw new TaskException.Forbidden("Only the assignee or an admin can dismiss");
        }
        Instant now = clock.now();
        task.status = TaskStatus.dismissed;
        task.dismissedBy = caller.userId();
        task.dismissalReason = DismissalReason.manual;
        task.updatedAt = now;
        return task;
    }

    @Transactional
    public Task reassign(UUID householdId, UUID taskId) {
        callerService.requireAdmin(householdId);
        Task task = requireTask(householdId, taskId);
        if (task.status != TaskStatus.open) {
            throw new TaskException.Conflict("Only open tasks can be reassigned");
        }
        TaskTemplate template =
                TaskTemplate.findInHousehold(householdId, task.templateId)
                        .orElseThrow(() -> new TaskException.NotFound("Template not found"));
        List<UUID> eligible = membershipGateway.listEligibleAssigneeIds(householdId);
        UUID next =
                RoundRobin.next(eligible, task.assigneeId)
                        .orElseThrow(
                                () ->
                                        new TaskException.Conflict(
                                                "No eligible members for reassignment"));
        if (next.equals(task.assigneeId) && eligible.size() == 1) {
            // only one eligible — still "reassign" to self is a no-op conflict
            throw new TaskException.Conflict("No other eligible member to reassign to");
        }
        // if only one person and it's the assignee, next wraps to self
        if (next.equals(task.assigneeId)) {
            throw new TaskException.Conflict("No other eligible member to reassign to");
        }
        task.assigneeId = next;
        task.updatedAt = clock.now();
        advanceRotation(template.rotationId, next);
        return task;
    }


    @Transactional
    public Task revert(UUID householdId, UUID taskId, String reason) {
        MemberView admin = callerService.requireAdmin(householdId);
        Task task = requireTask(householdId, taskId);
        if (task.status != TaskStatus.done) {
            throw new TaskException.Conflict("Only done tasks can be reverted");
        }
        if (reason == null || reason.isBlank()) {
            throw new TaskException.BadRequest("Reversion reason is required");
        }
        if (task.pointsAwarded == null || task.pointsAwarded <= 0) {
            throw new TaskException.Conflict("Task has no points to reverse");
        }
        Instant now = clock.now();
        TaskStatus resultingStatus;
        DismissalReason dismissalReason = null;
        if (task.origin == TaskOrigin.manual) {
            resultingStatus = TaskStatus.reverted;
        } else if (task.dueAt != null && !now.isAfter(task.dueAt)) {
            resultingStatus = TaskStatus.open;
        } else {
            resultingStatus = TaskStatus.dismissed;
            dismissalReason = DismissalReason.reverted_overdue;
        }

        pointsLedgerClient.reverse(
                householdId,
                task.id,
                task.assigneeId,
                task.pointsAwarded,
                admin.userId(),
                reason.trim(),
                resultingStatus.name());

        task.status = resultingStatus;
        task.completerId = null;
        task.completedAt = null;
        task.pointsAwarded = null;
        if (resultingStatus == TaskStatus.dismissed) {
            task.dismissedBy = admin.userId();
            task.dismissalReason = dismissalReason;
        }
        task.updatedAt = now;
        return task;
    }

    /** Reassign all open tasks for an away member (T-0003 hook). */
    @Transactional
    public int reassignOpenTasksForAwayMember(UUID householdId, UUID awayUserId) {
        callerService.requireAdmin(householdId);
        List<Task> open = Task.listOpenForAssignee(householdId, awayUserId);
        int count = 0;
        for (Task task : open) {
            reassignInternal(householdId, task);
            count++;
        }
        return count;
    }

    /** Dismisses every open task of a member who was marked away (admin only). */
    @Transactional
    public int dismissOpenTasksForAwayMember(UUID householdId, UUID awayUserId) {
        MemberView admin = callerService.requireAdmin(householdId);
        Instant now = clock.now();
        List<Task> open = Task.listOpenForAssignee(householdId, awayUserId);
        for (Task task : open) {
            task.status = TaskStatus.dismissed;
            task.dismissedBy = admin.userId();
            task.dismissalReason = DismissalReason.assignee_away;
            task.updatedAt = now;
        }
        return open.size();
    }

    private void reassignInternal(UUID householdId, Task task) {
        TaskTemplate template =
                TaskTemplate.findInHousehold(householdId, task.templateId)
                        .orElseThrow(() -> new TaskException.NotFound("Template not found"));
        List<UUID> eligible = membershipGateway.listEligibleAssigneeIds(householdId);
        UUID next =
                RoundRobin.next(eligible, task.assigneeId)
                        .orElseThrow(
                                () ->
                                        new TaskException.Conflict(
                                                "No eligible members for reassignment"));
        if (next.equals(task.assigneeId)) {
            return;
        }
        task.assigneeId = next;
        task.updatedAt = clock.now();
        advanceRotation(template.rotationId, next);
    }

    private UUID resolveAssignee(UUID householdId, TaskTemplate template, UUID requested) {
        List<UUID> eligible = membershipGateway.listEligibleAssigneeIds(householdId);
        if (requested != null) {
            if (!eligible.contains(requested)) {
                throw new TaskException.BadRequest("Assignee is not eligible");
            }
            return requested;
        }
        Rotation rotation =
                Rotation.findOptionalById(template.rotationId)
                        .orElseThrow(() -> new TaskException.NotFound("Rotation not found"));
        return RoundRobin.next(eligible, rotation.lastAssignedUserId)
                .orElseThrow(
                        () -> new TaskException.Conflict("No eligible members to assign"));
    }

    private TaskTemplate requireActiveTemplate(UUID householdId, UUID templateId) {
        return TaskTemplate.findActive(householdId, templateId)
                .orElseThrow(() -> new TaskException.NotFound("Template not found or archived"));
    }

    private Task requireTask(UUID householdId, UUID taskId) {
        return Task.findInHousehold(householdId, taskId)
                .orElseThrow(() -> new TaskException.NotFound("Task not found"));
    }

    private static Task snapshotTask(
            UUID householdId,
            TaskTemplate template,
            TaskOrigin origin,
            UUID assigneeId,
            Instant dueAt,
            Instant now) {
        Task task = new Task();
        task.id = UUID.randomUUID();
        task.householdId = householdId;
        task.templateId = template.id;
        task.origin = origin;
        task.title = template.title;
        task.emoji = template.emoji;
        task.description = template.description;
        task.points = template.points;
        task.latePoints = template.latePoints;
        task.assigneeId = assigneeId;
        task.dueAt = dueAt;
        task.createdAt = now;
        task.updatedAt = now;
        return task;
    }

    private void advanceRotation(UUID rotationId, UUID assigneeId) {
        Rotation rotation =
                Rotation.findOptionalById(rotationId)
                        .orElseThrow(() -> new TaskException.NotFound("Rotation not found"));
        rotation.lastAssignedUserId = assigneeId;
    }
}
