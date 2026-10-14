package com.betterhome.common;

import java.time.Duration;

/**
 * How long an outbox relay waits before it tries a failed row again: 5 s, doubling, up to 15 min.
 */
public final class RelayBackoff {

    private static final Duration FIRST = Duration.ofSeconds(5);
    private static final Duration CAP = Duration.ofMinutes(15);

    private RelayBackoff() {}

    /** The wait after the given number of failed attempts (1 for the first failure). */
    public static Duration delay(int failedAttempts) {
        if (failedAttempts < 1) {
            throw new IllegalArgumentException("failedAttempts must be at least 1");
        }
        long factor = 1L << Math.min(failedAttempts - 1, 20);
        Duration delay = FIRST.multipliedBy(factor);
        return delay.compareTo(CAP) > 0 ? CAP : delay;
    }
}
