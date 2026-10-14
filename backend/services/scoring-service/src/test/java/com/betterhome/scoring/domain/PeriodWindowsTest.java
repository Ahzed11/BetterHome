package com.betterhome.scoring.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.scoring.domain.PeriodWindows.Window;
import java.time.Duration;
import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class PeriodWindowsTest {

    private static final ZoneId BRUSSELS = ZoneId.of("Europe/Brussels");
    private static final ZoneId NEW_YORK = ZoneId.of("America/New_York");

    private static Instant at(String iso) {
        return Instant.parse(iso);
    }

    @Test
    void aMonthInUtcRunsFromMidnightToMidnight() {
        Window march = PeriodWindows.month(YearMonth.of(2026, 3), ZoneOffset.UTC);

        assertEquals(at("2026-03-01T00:00:00Z"), march.from());
        assertEquals(at("2026-04-01T00:00:00Z"), march.to());
        assertEquals("2026-03", march.label());
    }

    @Test
    void aMonthInBrusselsStartsAndEndsAtLocalMidnightWhateverTheOffset() {
        // March 2026 starts in CET (+1) and ends in CEST (+2): DST began on 29 March.
        Window march = PeriodWindows.month(YearMonth.of(2026, 3), BRUSSELS);

        assertEquals(at("2026-02-28T23:00:00Z"), march.from());
        assertEquals(at("2026-03-31T22:00:00Z"), march.to());
        assertEquals(Duration.ofDays(31).minusHours(1), Duration.between(march.from(), march.to()));
    }

    @Test
    void theClocksGoingBackMakeAMonthAnHourLonger() {
        // New York fell back on 1 November 2026: October gains an hour in the local calendar.
        Window october = PeriodWindows.month(YearMonth.of(2026, 10), NEW_YORK);
        Window november = PeriodWindows.month(YearMonth.of(2026, 11), NEW_YORK);

        assertEquals(at("2026-10-01T04:00:00Z"), october.from());
        assertEquals(at("2026-11-01T04:00:00Z"), october.to());
        assertEquals(Duration.ofDays(31), Duration.between(october.from(), october.to()));
        assertEquals(at("2026-12-01T05:00:00Z"), november.to());
        assertEquals(
                Duration.ofDays(30).plusHours(1), Duration.between(november.from(), november.to()));
    }

    @Test
    void aSpringForwardMonthIsAnHourShorter() {
        Window march = PeriodWindows.month(YearMonth.of(2026, 3), NEW_YORK);

        assertEquals(Duration.ofDays(31).minusHours(1), Duration.between(march.from(), march.to()));
        assertEquals(at("2026-04-01T04:00:00Z"), march.to());
    }

    @Test
    void anInstantOnTheBoundaryBelongsToTheNewMonth() {
        Instant boundary = at("2026-03-31T22:00:00Z");

        assertEquals(YearMonth.of(2026, 4), PeriodWindows.monthOf(boundary, BRUSSELS));
        assertEquals(
                YearMonth.of(2026, 3), PeriodWindows.monthOf(boundary.minusNanos(1), BRUSSELS));
        assertEquals(boundary, PeriodWindows.endOfMonth(YearMonth.of(2026, 3), BRUSSELS));
    }

    @Test
    void aWeekStartsOnMondayAtLocalMidnight() {
        // Sunday 11 October 2026, 22:30 UTC, is already Monday 12 October in Brussels (+2).
        Window week =
                PeriodWindows.of(ScorePeriod.week, BRUSSELS, at("2026-10-11T22:30:00Z"), null);

        assertEquals(at("2026-10-11T22:00:00Z"), week.from());
        assertEquals(at("2026-10-18T22:00:00Z"), week.to());
        assertNull(week.label());
    }

    @Test
    void inUtcTheSameInstantIsStillTheWeekBefore() {
        Window week =
                PeriodWindows.of(
                        ScorePeriod.week, ZoneOffset.UTC, at("2026-10-11T22:30:00Z"), null);

        assertEquals(at("2026-10-05T00:00:00Z"), week.from());
        assertEquals(at("2026-10-12T00:00:00Z"), week.to());
    }

    @Test
    void aWeekContainingADaylightSavingChangeIsAnHourShorterOrLonger() {
        // Weeks of Mon 2 Mar (clocks forward on Sun 8 Mar) and Mon 26 Oct (back on Sun 1 Nov).
        Window spring =
                PeriodWindows.of(ScorePeriod.week, NEW_YORK, at("2026-03-04T12:00:00Z"), null);
        Window autumn =
                PeriodWindows.of(ScorePeriod.week, NEW_YORK, at("2026-10-28T12:00:00Z"), null);

        assertEquals(
                Duration.ofDays(7).minusHours(1), Duration.between(spring.from(), spring.to()));
        assertEquals(Duration.ofDays(7).plusHours(1), Duration.between(autumn.from(), autumn.to()));
    }

    @Test
    void aYearIsCutAtLocalNewYear() {
        Window year =
                PeriodWindows.of(ScorePeriod.year, BRUSSELS, at("2025-12-31T23:30:00Z"), null);

        // 23:30 UTC on 31 December is 00:30 on 1 January in Brussels: already 2026 there.
        assertEquals("2026", year.label());
        assertEquals(at("2025-12-31T23:00:00Z"), year.from());
        assertEquals(at("2026-12-31T23:00:00Z"), year.to());
    }

    @Test
    void allTimeHasNoBounds() {
        Window all = PeriodWindows.of(ScorePeriod.all, BRUSSELS, at("2026-10-14T10:00:00Z"), null);

        assertNull(all.from());
        assertNull(all.to());
        assertNull(all.label());
    }

    @Test
    void aGivenMonthOverridesTheCurrentOneOnlyForTheMonthPeriod() {
        Instant now = at("2026-10-14T10:00:00Z");

        assertEquals(
                "2026-03",
                PeriodWindows.of(ScorePeriod.month, BRUSSELS, now, YearMonth.of(2026, 3)).label());
        assertEquals("2026-10", PeriodWindows.of(ScorePeriod.month, BRUSSELS, now, null).label());
        assertEquals(
                "2026",
                PeriodWindows.of(ScorePeriod.year, BRUSSELS, now, YearMonth.of(2026, 3)).label());
    }

    @Test
    void zonesWhereMidnightDoesNotExistOnTheChangeDayStillGiveContiguousWindows() {
        // Havana springs forward at midnight, so 8 March 2026 has no 00:00 there.
        ZoneId havana = ZoneId.of("America/Havana");

        Window week = PeriodWindows.of(ScorePeriod.week, havana, at("2026-03-08T12:00:00Z"), null);
        Window next = PeriodWindows.of(ScorePeriod.week, havana, week.to(), null);

        assertEquals(week.to(), next.from());
        assertTrue(week.from().isBefore(week.to()));
    }

    @Test
    void extremeOffsetsAndHalfHourDaylightSavingWork() {
        for (String id :
                List.of(
                        "Pacific/Kiritimati",
                        "Pacific/Pago_Pago",
                        "Australia/Lord_Howe",
                        "Asia/Kolkata")) {
            ZoneId zone = ZoneId.of(id);
            Instant now = at("2026-10-14T10:00:00Z");

            Window month = PeriodWindows.of(ScorePeriod.month, zone, now, null);

            assertTrue(!now.isBefore(month.from()) && now.isBefore(month.to()), id);
            assertEquals(
                    0,
                    ZonedDateTime.ofInstant(month.from(), zone).toLocalTime().toSecondOfDay(),
                    id + " starts at local midnight");
        }
    }

    @Test
    void everyZoneHasContiguousMonthsAndEveryInstantIsInItsOwnWindows() {
        List<Instant> samples =
                List.of(
                        at("2026-01-01T00:00:00Z"),
                        at("2026-03-08T07:00:00Z"),
                        at("2026-03-29T01:00:00Z"),
                        at("2026-06-15T12:00:00Z"),
                        at("2026-10-25T01:30:00Z"),
                        at("2026-11-01T06:00:00Z"),
                        at("2026-12-31T23:59:59Z"));
        for (String id : ZoneId.getAvailableZoneIds()) {
            ZoneId zone = ZoneId.of(id);
            for (int month = 1; month <= 12; month++) {
                YearMonth current = YearMonth.of(2026, month);
                assertEquals(
                        PeriodWindows.month(current, zone).to(),
                        PeriodWindows.month(current.plusMonths(1), zone).from(),
                        id + " " + current);
            }
            for (Instant now : samples) {
                for (ScorePeriod period :
                        List.of(ScorePeriod.week, ScorePeriod.month, ScorePeriod.year)) {
                    Window window = PeriodWindows.of(period, zone, now, null);
                    assertTrue(
                            !now.isBefore(window.from()) && now.isBefore(window.to()),
                            id + " " + period + " " + now);
                }
            }
        }
    }
}
