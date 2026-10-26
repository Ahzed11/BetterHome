package com.betterhome.common.testclock;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.SystemClock;
import com.betterhome.common.testclock.TestClockResource.ClockState;
import com.betterhome.common.testclock.TestClockResource.SetClock;
import jakarta.ws.rs.NotFoundException;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class TestClockResourceTest {

    @Test
    void movesTheClockAheadAndBackWhenEnabled() {
        SystemClock clock = new SystemClock();
        TestClockResource resource = new TestClockResource(true, clock);

        ClockState ahead = resource.set(new SetClock(36 * 3600));
        assertEquals(36 * 3600, ahead.offsetSeconds());
        assertEquals(Duration.ofHours(36), clock.offset());
        assertTrue(Instant.parse(ahead.now()).isAfter(Instant.now().plus(Duration.ofHours(35))));
        assertEquals(36 * 3600, resource.get().offsetSeconds());

        ClockState back = resource.set(new SetClock(0));
        assertEquals(0, back.offsetSeconds());
        assertEquals(Duration.ZERO, clock.offset());
    }

    @Test
    void doesNotExistWhenNotEnabledAndLeavesTheClockAlone() {
        SystemClock clock = new SystemClock();
        TestClockResource resource = new TestClockResource(false, clock);

        assertThrows(NotFoundException.class, resource::get);
        assertThrows(NotFoundException.class, () -> resource.set(new SetClock(3600)));
        assertEquals(Duration.ZERO, clock.offset());
    }
}
