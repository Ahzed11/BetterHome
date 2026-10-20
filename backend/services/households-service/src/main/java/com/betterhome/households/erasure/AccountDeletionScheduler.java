package com.betterhome.households.erasure;

import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/** Retries account deletions that could not reach every target the first time. */
@ApplicationScoped
public class AccountDeletionScheduler {

    private final AccountDeletionProcessor processor;

    @Inject
    public AccountDeletionScheduler(AccountDeletionProcessor processor) {
        this.processor = processor;
    }

    @Scheduled(every = "15s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void retryPendingDeletions() {
        processor.processDue(20);
    }
}
