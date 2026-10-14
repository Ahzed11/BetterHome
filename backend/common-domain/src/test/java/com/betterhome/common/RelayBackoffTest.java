package com.betterhome.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import org.junit.jupiter.api.Test;

class RelayBackoffTest {

    @Test
    void startsAtFiveSecondsAndDoubles() {
        assertEquals(Duration.ofSeconds(5), RelayBackoff.delay(1));
        assertEquals(Duration.ofSeconds(10), RelayBackoff.delay(2));
        assertEquals(Duration.ofSeconds(20), RelayBackoff.delay(3));
    }

    @Test
    void neverExceedsFifteenMinutes() {
        assertEquals(Duration.ofMinutes(15), RelayBackoff.delay(9));
        assertEquals(Duration.ofMinutes(15), RelayBackoff.delay(1_000));
    }

    @Test
    void growsWithEveryAttemptUntilTheCap() {
        for (int attempt = 1; attempt < 8; attempt++) {
            assertTrue(
                    RelayBackoff.delay(attempt + 1).compareTo(RelayBackoff.delay(attempt)) > 0,
                    "attempt " + attempt);
        }
    }

    @Test
    void rejectsAnAttemptCountBelowOne() {
        assertThrows(IllegalArgumentException.class, () -> RelayBackoff.delay(0));
    }
}
