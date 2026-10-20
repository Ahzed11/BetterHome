package com.betterhome.households.service;

import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class AwayStartScheduler {

    private final AwayStartDismissal awayStartDismissal;

    @Inject
    public AwayStartScheduler(AwayStartDismissal awayStartDismissal) {
        this.awayStartDismissal = awayStartDismissal;
    }

    @Scheduled(every = "30s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void dismissStartedAwayPeriods() {
        awayStartDismissal.dismissDue();
    }
}
