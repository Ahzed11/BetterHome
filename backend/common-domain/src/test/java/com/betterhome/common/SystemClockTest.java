package com.betterhome.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class SystemClockTest {

    @Test
    void nowReturnsUtcInstantCloseToSystemTime() {
        SystemClock clock = new SystemClock();
        Instant before = Instant.now().minusSeconds(1);
        Instant actual = clock.now();
        Instant after = Instant.now().plusSeconds(1);

        assertNotNull(actual);
        assertFalse(actual.isBefore(before));
        assertTrue(!actual.isAfter(after));
    }

    @Test
    void successiveReadingsNeverGoBackwards() {
        SystemClock clock = new SystemClock();
        Instant first = clock.now();
        Instant second = clock.now();

        assertFalse(second.isBefore(first));
    }

    @Test
    void runsAheadOfTheSystemTimeByTheShiftAndBackWhenItIsRemoved() {
        SystemClock clock = new SystemClock();
        assertEquals(Duration.ZERO, clock.offset());

        clock.shiftBy(Duration.ofDays(2));
        Instant shifted = clock.now();
        assertEquals(Duration.ofDays(2), clock.offset());
        assertTrue(shifted.isAfter(Instant.now().plus(Duration.ofDays(2)).minusSeconds(5)));
        assertTrue(shifted.isBefore(Instant.now().plus(Duration.ofDays(2)).plusSeconds(5)));

        clock.shiftBy(Duration.ZERO);
        assertTrue(clock.now().isBefore(Instant.now().plusSeconds(5)));
    }
}
