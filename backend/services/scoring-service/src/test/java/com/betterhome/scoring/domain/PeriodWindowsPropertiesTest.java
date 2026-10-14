package com.betterhome.scoring.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.scoring.domain.PeriodWindows.Window;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.constraints.IntRange;

/** The window calculator holds for every zone and every instant between 2000 and 2100. */
class PeriodWindowsPropertiesTest {

    private static final long YEAR_2000 = 946_684_800L;
    private static final long YEAR_2100 = 4_102_444_800L;

    @Provide
    Arbitrary<ZoneId> zones() {
        List<String> ids = new ArrayList<>(ZoneId.getAvailableZoneIds());
        Collections.sort(ids);
        return Arbitraries.of(ids).map(ZoneId::of);
    }

    @Provide
    Arbitrary<Instant> instants() {
        return Arbitraries.longs().between(YEAR_2000, YEAR_2100).map(Instant::ofEpochSecond);
    }

    @Property
    void everyInstantIsInsideItsOwnWeekMonthAndYear(
            @ForAll("zones") ZoneId zone, @ForAll("instants") Instant now) {
        for (ScorePeriod period : List.of(ScorePeriod.week, ScorePeriod.month, ScorePeriod.year)) {
            Window window = PeriodWindows.of(period, zone, now, null);

            assertTrue(!now.isBefore(window.from()), period + " starts after " + now);
            assertTrue(now.isBefore(window.to()), period + " ends before " + now);
        }
    }

    @Property
    void monthsFollowEachOtherWithNeitherGapNorOverlap(
            @ForAll("zones") ZoneId zone,
            @ForAll @IntRange(min = 2000, max = 2099) int year,
            @ForAll @IntRange(min = 1, max = 12) int month) {
        YearMonth current = YearMonth.of(year, month);

        assertEquals(
                PeriodWindows.month(current, zone).to(),
                PeriodWindows.month(current.plusMonths(1), zone).from());
    }

    @Property
    void weeksFollowEachOtherAndStartOnAMondayAtLocalMidnight(
            @ForAll("zones") ZoneId zone, @ForAll("instants") Instant now) {
        Window week = PeriodWindows.of(ScorePeriod.week, zone, now, null);
        Window next = PeriodWindows.of(ScorePeriod.week, zone, week.to(), null);

        assertEquals(week.to(), next.from(), "no gap and no overlap");
        ZonedDateTime start = ZonedDateTime.ofInstant(week.from(), zone);
        assertEquals(DayOfWeek.MONDAY, start.getDayOfWeek());
        assertTrue(
                start.toLocalTime().toSecondOfDay() <= 3600 * 3,
                "local midnight, or the first valid time after a change at midnight");
    }

    @Property
    void anInstantOnTheBoundaryBelongsToTheNewMonthAndOneBeforeBelongsToTheOld(
            @ForAll("zones") ZoneId zone,
            @ForAll @IntRange(min = 2000, max = 2099) int year,
            @ForAll @IntRange(min = 1, max = 12) int month) {
        YearMonth current = YearMonth.of(year, month);
        Instant boundary = PeriodWindows.endOfMonth(current, zone);

        assertEquals(current.plusMonths(1), PeriodWindows.monthOf(boundary, zone));
        assertEquals(current, PeriodWindows.monthOf(boundary.minusNanos(1), zone));
    }

    @Property
    void aMonthWindowCoversExactlyTheInstantsThatAreInThatMonthLocally(
            @ForAll("zones") ZoneId zone, @ForAll("instants") Instant instant) {
        YearMonth local = PeriodWindows.monthOf(instant, zone);
        Window window = PeriodWindows.month(local, zone);

        assertTrue(!instant.isBefore(window.from()) && instant.isBefore(window.to()));
    }
}
