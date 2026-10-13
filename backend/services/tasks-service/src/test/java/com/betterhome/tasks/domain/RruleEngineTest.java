package com.betterhome.tasks.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class RruleEngineTest {

    @Test
    void dailyInterval() {
        ZoneId zone = ZoneId.of("UTC");
        Instant start = ZonedDateTime.of(2026, 3, 1, 9, 0, 0, 0, zone).toInstant();
        Instant next =
                RruleEngine.nextOccurrence("FREQ=DAILY;INTERVAL=2", zone, start, null, start)
                        .orElseThrow();
        assertEquals(ZonedDateTime.of(2026, 3, 3, 9, 0, 0, 0, zone).toInstant(), next);
    }

    @Test
    void weeklyByDay() {
        ZoneId zone = ZoneId.of("UTC");
        Instant start = ZonedDateTime.of(2026, 3, 2, 8, 0, 0, 0, zone).toInstant(); // Monday
        Instant next =
                RruleEngine.nextOccurrence(
                                "FREQ=WEEKLY;BYDAY=WE", zone, start, null, start.minusSeconds(1))
                        .orElseThrow();
        assertEquals(LocalDate.of(2026, 3, 4), next.atZone(zone).toLocalDate()); // Wednesday
    }

    @Test
    void respectsEuropeParisDstSpringForward() {
        ZoneId zone = ZoneId.of("Europe/Paris");
        // 2026-03-29 is DST start in Europe; local 02:00 does not exist
        Instant start =
                ZonedDateTime.of(LocalDate.of(2026, 3, 28), LocalTime.of(9, 0), zone).toInstant();
        Instant next =
                RruleEngine.nextOccurrence("FREQ=DAILY", zone, start, null, start).orElseThrow();
        ZonedDateTime zoned = next.atZone(zone);
        assertEquals(LocalDate.of(2026, 3, 29), zoned.toLocalDate());
        assertEquals(9, zoned.getHour());
    }

    @Test
    void endsAtStopsOccurrences() {
        ZoneId zone = ZoneId.of("UTC");
        Instant start = Instant.parse("2026-01-01T10:00:00Z");
        Instant end = Instant.parse("2026-01-02T10:00:00Z");
        Optional<Instant> afterEnd =
                RruleEngine.nextOccurrence(
                        "FREQ=DAILY", zone, start, end, Instant.parse("2026-01-02T10:00:00Z"));
        assertTrue(afterEnd.isEmpty());
    }
}
