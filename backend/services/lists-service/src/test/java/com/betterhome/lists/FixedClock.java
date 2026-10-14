package com.betterhome.lists;

import com.betterhome.common.Clock;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.time.Instant;

/** Test clock that only moves when a test says so. */
@Alternative
@Priority(1)
@ApplicationScoped
public class FixedClock implements Clock {

    private volatile Instant now = Instant.parse("2026-03-01T10:00:00Z");

    public void set(Instant instant) {
        now = instant;
    }

    @Override
    public Instant now() {
        return now;
    }
}
