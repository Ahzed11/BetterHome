package com.betterhome.tasks;

import com.betterhome.common.Clock;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.time.Instant;

/**
 * Time source for tests. Follows the system time until a test fixes it, so tests that do not care
 * about time are unaffected.
 */
@Alternative
@Priority(1)
@ApplicationScoped
public class TestClock implements Clock {

    private volatile Instant fixed;

    public void fixAt(Instant instant) {
        this.fixed = instant;
    }

    public void useSystemTime() {
        this.fixed = null;
    }

    @Override
    public Instant now() {
        Instant current = fixed;
        return current != null ? current : Instant.now();
    }
}
