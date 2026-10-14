package com.betterhome.households.scheduler;

import com.betterhome.households.service.OutboxRelay;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/** Runs the outbox relay; several replicas may run it at once, the relay claims rows safely. */
@ApplicationScoped
public class OutboxScheduler {

    private final OutboxRelay outboxRelay;

    @Inject
    public OutboxScheduler(OutboxRelay outboxRelay) {
        this.outboxRelay = outboxRelay;
    }

    @Scheduled(every = "15s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void relayOutbox() {
        outboxRelay.relayDue(50);
    }
}
