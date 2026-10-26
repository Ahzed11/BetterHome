package com.betterhome.common;

import jakarta.enterprise.context.ApplicationScoped;
import java.time.Duration;
import java.time.Instant;

/**
 * The wall clock. In the end-to-end environment only, {@link #shiftBy} moves it so that journeys
 * can reach a due date without waiting for it (see {@code TestClockResource}).
 */
@ApplicationScoped
public class SystemClock implements Clock {

    private volatile Duration offset = Duration.ZERO;

    @Override
    public Instant now() {
        return Instant.now().plus(offset);
    }

    public Duration offset() {
        return offset;
    }

    public void shiftBy(Duration shift) {
        this.offset = shift;
    }
}
