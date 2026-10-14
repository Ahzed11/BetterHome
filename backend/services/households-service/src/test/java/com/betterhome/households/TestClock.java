package com.betterhome.households;

import com.betterhome.common.Clock;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.time.Duration;
import java.time.Instant;

/** Follows real time until a test moves it forward, so time-dependent flows need no sleeping. */
@Alternative
@Priority(1)
@ApplicationScoped
public class TestClock implements Clock {

    private volatile Duration offset = Duration.ZERO;

    @Override
    public Instant now() {
        return Instant.now().plus(offset);
    }

    public void advance(Duration duration) {
        offset = offset.plus(duration);
    }

    public void reset() {
        offset = Duration.ZERO;
    }
}
