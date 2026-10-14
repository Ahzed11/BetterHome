package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.membership.MembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.HouseholdSettings;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class ReminderService {

    private final MembershipGateway membershipGateway;
    private final OutboxService outboxService;
    private final Clock clock;
    private final EntityManager entityManager;

    @Inject
    public ReminderService(
            MembershipGateway membershipGateway,
            OutboxService outboxService,
            Clock clock,
            EntityManager entityManager) {
        this.membershipGateway = membershipGateway;
        this.outboxService = outboxService;
        this.clock = clock;
        this.entityManager = entityManager;
    }

    @Transactional
    public int sendDueReminders() {
        Instant now = clock.now();
        List<Task> candidates =
                Task.find(
                                "status = ?1 and dueAt is not null and dueReminderSentAt is null",
                                TaskStatus.open)
                        .list();
        int sent = 0;
        for (Task task : candidates) {
            HouseholdSettings settings = membershipGateway.householdSettings(task.householdId);
            ZoneId zone;
            try {
                zone = ZoneId.of(settings.timezone());
            } catch (Exception ex) {
                zone = ZoneId.of("UTC");
            }
            LocalDate dueDate = task.dueAt.atZone(zone).toLocalDate();
            ZonedDateTime reminderAt =
                    dueDate.minusDays(settings.reminderDaysBefore())
                            .atTime(settings.reminderTime())
                            .atZone(zone);
            if (!now.isBefore(reminderAt.toInstant())) {
                outboxService.enqueueForTask(task, task.assigneeId, "due_reminder");
                task.dueReminderSentAt = now;
                task.updatedAt = now;
                sent++;
            }
        }
        return sent;
    }

    /**
     * Tells the assignee of every open task past its due date, once. Rows are claimed with {@code
     * FOR UPDATE SKIP LOCKED}, so replicas never queue the same notice twice.
     */
    @Transactional
    public int sendOverdueNotices(int limit) {
        Instant now = clock.now();
        List<?> ids =
                entityManager
                        .createNativeQuery(
                                """
                                SELECT id FROM task
                                WHERE status = 'open' AND due_at IS NOT NULL AND due_at < :now
                                  AND overdue_notified_at IS NULL
                                ORDER BY due_at
                                FOR UPDATE SKIP LOCKED
                                LIMIT :lim
                                """)
                        .setParameter("now", java.sql.Timestamp.from(now))
                        .setParameter("lim", Math.max(limit, 1))
                        .getResultList();
        for (Object rawId : ids) {
            UUID id = rawId instanceof UUID uuid ? uuid : UUID.fromString(rawId.toString());
            Task task = Task.findById(id);
            outboxService.enqueueForTask(task, task.assigneeId, "overdue");
            task.overdueNotifiedAt = now;
            task.updatedAt = now;
        }
        return ids.size();
    }
}
