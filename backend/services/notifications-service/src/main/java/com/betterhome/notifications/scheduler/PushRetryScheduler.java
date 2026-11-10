package com.betterhome.notifications.scheduler;

import com.betterhome.notifications.service.PushDelivery;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/** Tries again the pushes Gotify could not take. */
@ApplicationScoped
public class PushRetryScheduler {

    private final PushDelivery pushDelivery;

    @Inject
    public PushRetryScheduler(PushDelivery pushDelivery) {
        this.pushDelivery = pushDelivery;
    }

    @Scheduled(every = "15s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void retryPushes() {
        pushDelivery.retryDue(50);
    }
}
