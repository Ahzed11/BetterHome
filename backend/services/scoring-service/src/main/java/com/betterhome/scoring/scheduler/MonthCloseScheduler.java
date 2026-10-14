package com.betterhome.scoring.scheduler;

import com.betterhome.scoring.service.MonthCloser;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/** Runs the monthly close; several replicas may run it at once, the closer claims rows safely. */
@ApplicationScoped
public class MonthCloseScheduler {

    private final MonthCloser monthCloser;

    @Inject
    public MonthCloseScheduler(MonthCloser monthCloser) {
        this.monthCloser = monthCloser;
    }

    @Scheduled(every = "5m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void closeEndedMonths() {
        monthCloser.closeDue(50);
    }
}
