package com.betterhome.tasks.scheduler;

import com.betterhome.tasks.service.OutboxService;
import com.betterhome.tasks.service.RecurrenceSpawnService;
import com.betterhome.tasks.service.ReminderService;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class AutomationScheduler {

    private final RecurrenceSpawnService spawnService;
    private final ReminderService reminderService;
    private final OutboxService outboxService;

    @Inject
    public AutomationScheduler(
            RecurrenceSpawnService spawnService,
            ReminderService reminderService,
            OutboxService outboxService) {
        this.spawnService = spawnService;
        this.reminderService = reminderService;
        this.outboxService = outboxService;
    }

    @Scheduled(every = "30s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void spawnDueRecurrences() {
        spawnService.claimAndSpawnDue(20);
    }

    @Scheduled(every = "60s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void sendReminders() {
        reminderService.sendDueReminders();
    }

    @Scheduled(every = "15s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void drainOutbox() {
        outboxService.drain(50);
    }
}
