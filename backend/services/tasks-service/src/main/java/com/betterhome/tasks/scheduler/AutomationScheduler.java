package com.betterhome.tasks.scheduler;

import com.betterhome.tasks.service.OutboxRelay;
import com.betterhome.tasks.service.RecurrenceSpawnService;
import com.betterhome.tasks.service.ReminderService;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class AutomationScheduler {

    private final RecurrenceSpawnService spawnService;
    private final ReminderService reminderService;
    private final OutboxRelay outboxRelay;

    @Inject
    public AutomationScheduler(
            RecurrenceSpawnService spawnService,
            ReminderService reminderService,
            OutboxRelay outboxRelay) {
        this.spawnService = spawnService;
        this.reminderService = reminderService;
        this.outboxRelay = outboxRelay;
    }

    @Scheduled(every = "30s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void spawnDueRecurrences() {
        spawnService.claimAndSpawnDue(20);
    }

    @Scheduled(every = "60s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void sendReminders() {
        reminderService.sendDueReminders();
        reminderService.sendOverdueNotices(100);
    }

    @Scheduled(every = "15s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void drainOutbox() {
        outboxRelay.relayDue(50);
    }
}
