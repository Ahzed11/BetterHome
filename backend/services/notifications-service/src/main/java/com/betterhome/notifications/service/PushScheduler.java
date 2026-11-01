package com.betterhome.notifications.service;

import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/** Tries again the pushes that the push server could not take (T-0105). */
@ApplicationScoped
public class PushScheduler {

    private final PushDelivery delivery;

    @Inject
    public PushScheduler(PushDelivery delivery) {
        this.delivery = delivery;
    }

    @Scheduled(every = "15s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void retryPushes() {
        delivery.retryDue(50);
    }
}
