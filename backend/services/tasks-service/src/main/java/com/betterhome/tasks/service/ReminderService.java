package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.membership.MembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.HouseholdSettings;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;

@ApplicationScoped
public class ReminderService {

    private final MembershipGateway membershipGateway;
    private final OutboxService outboxService;
    private final Clock clock;

    @Inject
    public ReminderService(
            MembershipGateway membershipGateway, OutboxService outboxService, Clock clock) {
        this.membershipGateway = membershipGateway;
        this.outboxService = outboxService;
        this.clock = clock;
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
                outboxService.enqueue(
                        task.householdId,
                        task.assigneeId,
                        "due_reminder",
                        "Reminder",
                        task.title,
                        "{\"taskId\":\"" + task.id + "\"}");
                task.dueReminderSentAt = now;
                task.updatedAt = now;
                sent++;
            }
        }
        return sent;
    }
}
