package com.betterhome.tasks.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.Example;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.constraints.IntRange;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/**
 * Every schedule the engine accepts produces occurrences that follow it exactly, in any zone and
 * across daylight saving changes (AGENTS 5.1: RRULE next-run computation across timezones and DST).
 * The expectations restate the schedule rules; they do not reuse the engine's own code.
 */
class RruleEnginePropertiesTest {

    private static final int CHAIN = 14;

    /** A schedule in plain data, so the checks can restate what it means. */
    record Schedule(String freq, int interval, List<DayOfWeek> days, Integer monthDay) {
        String rrule() {
            StringBuilder rule = new StringBuilder("FREQ=" + freq + ";INTERVAL=" + interval);
            if (!days.isEmpty()) {
                rule.append(";BYDAY=")
                        .append(
                                String.join(
                                        ",",
                                        days.stream().map(d -> d.name().substring(0, 2)).toList()));
            }
            if (monthDay != null) {
                rule.append(";BYMONTHDAY=").append(monthDay);
            }
            return rule.toString();
        }
    }

    @Provide
    Arbitrary<ZoneId> zones() {
        List<String> ids = new ArrayList<>(ZoneId.getAvailableZoneIds());
        Collections.sort(ids);
        return Arbitraries.of(ids).map(ZoneId::of);
    }

    /** Local start: any minute between 2024 and 2030. */
    @Provide
    Arbitrary<LocalDateTime> starts() {
        return Arbitraries.longs()
                .between(0, 7L * 365 * 24 * 60)
                .map(minutes -> LocalDateTime.of(2024, 1, 1, 0, 0).plusMinutes(minutes));
    }

    @Provide
    Arbitrary<Schedule> schedules() {
        Arbitrary<Schedule> daily =
                Arbitraries.integers()
                        .between(1, 9)
                        .map(i -> new Schedule("DAILY", i, List.of(), null));
        Arbitrary<Schedule> weekly =
                Arbitraries.integers()
                        .between(1, 4)
                        .flatMap(
                                interval ->
                                        Arbitraries.of(DayOfWeek.values())
                                                .list()
                                                .uniqueElements()
                                                .ofMaxSize(4)
                                                .map(
                                                        days ->
                                                                new Schedule(
                                                                        "WEEKLY", interval, days,
                                                                        null)));
        Arbitrary<Schedule> monthly =
                Arbitraries.integers()
                        .between(1, 6)
                        .flatMap(
                                interval ->
                                        Arbitraries.integers()
                                                .between(1, 31)
                                                .injectNull(0.3)
                                                .map(
                                                        day ->
                                                                new Schedule(
                                                                        "MONTHLY", interval,
                                                                        List.of(), day)));
        return Arbitraries.oneOf(daily, weekly, monthly);
    }

    private static List<Instant> chain(
            Schedule schedule, ZoneId zone, Instant startsAt, Instant endsAt) {
        List<Instant> occurrences = new ArrayList<>();
        Instant cursor = startsAt.minusSeconds(1);
        for (int i = 0; i < CHAIN; i++) {
            Optional<Instant> next =
                    RruleEngine.nextOccurrence(schedule.rrule(), zone, startsAt, endsAt, cursor);
            if (next.isEmpty()) {
                break;
            }
            assertTrue(next.get().isAfter(cursor), "strictly after " + cursor + ": " + next.get());
            occurrences.add(next.get());
            cursor = next.get();
        }
        return occurrences;
    }

    private static Instant at(LocalDateTime local, ZoneId zone) {
        return local.atZone(zone).toInstant();
    }

    /**
     * The local start the engine can see. It is given an {@code Instant}, so a start inside a
     * daylight saving gap has already moved forward by the gap (02:00 is 03:00): that moved time is
     * the time of day of the rule from then on, and what the expectations restate.
     */
    private static LocalDateTime seenBy(LocalDateTime start, ZoneId zone) {
        return at(start, zone).atZone(zone).toLocalDateTime();
    }

    /**
     * A start inside a daylight saving gap (clocks jump from 02:00 to 03:00 in Adak on 2029-03-11),
     * which the random generator only reaches on some seeds (CI of 2026-10-29, seed
     * -577492766145996246, T-0132). Every property that restates the time of day runs on it here.
     */
    @Example
    void aStartInsideADaylightSavingGapIsHandledByEveryProperty() {
        ZoneId zone = ZoneId.of("America/Adak");
        LocalDateTime start = LocalDateTime.of(2029, 3, 11, 2, 0);
        Schedule daily = new Schedule("DAILY", 1, List.of(), null);
        Schedule weekly = new Schedule("WEEKLY", 1, List.of(), null);

        aDailyRuleLeavesNoLocalDayOutAndKeepsTheLocalTimeOfDay(1, zone, start);
        everyOccurrenceIsOnADayTheScheduleNames(daily, zone, start);
        theEngineFindsExactlyTheOccurrencesTheScheduleNamesNoneMissedNoneInvented(
                daily, zone, start);
        theEngineFindsExactlyTheOccurrencesTheScheduleNamesNoneMissedNoneInvented(
                weekly, zone, start);
    }

    @Property
    void occurrencesComeInOrderNotBeforeTheStartAndNotAfterTheEnd(
            @ForAll("schedules") Schedule schedule,
            @ForAll("zones") ZoneId zone,
            @ForAll("starts") LocalDateTime start,
            @ForAll @IntRange(min = 1, max = 400) int endsAfterDays) {
        Instant startsAt = at(start, zone);
        Instant endsAt = startsAt.plus(endsAfterDays, ChronoUnit.DAYS);

        List<Instant> occurrences = chain(schedule, zone, startsAt, endsAt);

        for (Instant occurrence : occurrences) {
            assertTrue(!occurrence.isBefore(startsAt), "before the start");
            assertTrue(!occurrence.isAfter(endsAt), "after the end");
        }
    }

    @Property
    void everyOccurrenceIsOnADayTheScheduleNames(
            @ForAll("schedules") Schedule schedule,
            @ForAll("zones") ZoneId zone,
            @ForAll("starts") LocalDateTime start) {
        Instant startsAt = at(start, zone);
        LocalDate startDay = seenBy(start, zone).toLocalDate();

        for (Instant occurrence : chain(schedule, zone, startsAt, null)) {
            LocalDate day = occurrence.atZone(zone).toLocalDate();
            switch (schedule.freq()) {
                case "DAILY" -> {
                    long days = ChronoUnit.DAYS.between(startDay, day);
                    assertEquals(
                            0,
                            days % schedule.interval(),
                            "every " + schedule.interval() + " days");
                }
                case "WEEKLY" -> {
                    List<DayOfWeek> allowed =
                            schedule.days().isEmpty()
                                    ? List.of(startDay.getDayOfWeek())
                                    : schedule.days();
                    assertTrue(
                            allowed.contains(day.getDayOfWeek()),
                            day + " is not one of " + allowed);
                    long weeks =
                            ChronoUnit.WEEKS.between(
                                    startDay.with(
                                            TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)),
                                    day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)));
                    assertEquals(
                            0,
                            weeks % schedule.interval(),
                            "every " + schedule.interval() + " weeks");
                }
                default -> {
                    int wanted =
                            schedule.monthDay() != null
                                    ? schedule.monthDay()
                                    : startDay.getDayOfMonth();
                    assertEquals(wanted, day.getDayOfMonth(), "the requested day of the month");
                    long months =
                            ChronoUnit.MONTHS.between(
                                    startDay.withDayOfMonth(1), day.withDayOfMonth(1));
                    assertEquals(
                            0,
                            months % schedule.interval(),
                            "every " + schedule.interval() + " months");
                }
            }
        }
    }

    /**
     * Whether the schedule names this local day, restated from the rules (not the engine's code).
     */
    private static boolean named(Schedule schedule, LocalDate startDay, LocalDate day) {
        switch (schedule.freq()) {
            case "DAILY":
                {
                    long days = ChronoUnit.DAYS.between(startDay, day);
                    return days >= 0 && days % schedule.interval() == 0;
                }
            case "WEEKLY":
                {
                    List<DayOfWeek> allowed =
                            schedule.days().isEmpty()
                                    ? List.of(startDay.getDayOfWeek())
                                    : schedule.days();
                    long weeks =
                            ChronoUnit.WEEKS.between(
                                    startDay.with(
                                            TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)),
                                    day.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)));
                    return allowed.contains(day.getDayOfWeek())
                            && weeks >= 0
                            && weeks % schedule.interval() == 0;
                }
            default:
                {
                    int wanted =
                            schedule.monthDay() != null
                                    ? schedule.monthDay()
                                    : startDay.getDayOfMonth();
                    long months =
                            ChronoUnit.MONTHS.between(
                                    startDay.withDayOfMonth(1), day.withDayOfMonth(1));
                    return day.getDayOfMonth() == wanted
                            && months >= 0
                            && months % schedule.interval() == 0;
                }
        }
    }

    @Property
    void theEngineFindsExactlyTheOccurrencesTheScheduleNamesNoneMissedNoneInvented(
            @ForAll("schedules") Schedule schedule,
            @ForAll("zones") ZoneId zone,
            @ForAll("starts") LocalDateTime start) {
        Instant startsAt = at(start, zone);
        LocalDateTime seen = seenBy(start, zone);
        List<Instant> expected = new ArrayList<>();
        for (int offset = 0; offset < 3000 && expected.size() < CHAIN; offset++) {
            LocalDate day = seen.toLocalDate().plusDays(offset);
            if (named(schedule, seen.toLocalDate(), day)) {
                Instant occurrence = at(day.atTime(seen.toLocalTime()), zone);
                if (!occurrence.atZone(zone).toLocalDate().equals(day)) {
                    occurrence = at(day.plusDays(1).atStartOfDay(), zone).minusSeconds(1);
                }
                if (!occurrence.isBefore(startsAt)) {
                    expected.add(occurrence);
                }
            }
        }

        List<Instant> found = chain(schedule, zone, startsAt, null);

        assertTrue(
                found.size() >= expected.size(),
                "missed occurrences: expected " + expected + " found " + found);
        assertEquals(expected, found.subList(0, expected.size()));
    }

    @Property
    void aDailyRuleLeavesNoLocalDayOutAndKeepsTheLocalTimeOfDay(
            @ForAll @IntRange(min = 1, max = 3) int interval,
            @ForAll("zones") ZoneId zone,
            @ForAll("starts") LocalDateTime start) {
        Schedule daily = new Schedule("DAILY", interval, List.of(), null);
        Instant startsAt = at(start, zone);
        LocalDateTime seen = seenBy(start, zone);

        List<Instant> occurrences = chain(daily, zone, startsAt, null);

        for (int i = 0; i < occurrences.size(); i++) {
            LocalDateTime local = occurrences.get(i).atZone(zone).toLocalDateTime();
            assertEquals(
                    seen.toLocalDate().plusDays((long) i * interval),
                    local.toLocalDate(),
                    "no day skipped");
            if (zone.getRules()
                            .getValidOffsets(local.toLocalDate().atTime(seen.toLocalTime()))
                            .size()
                    == 1) {
                assertEquals(
                        seen.toLocalTime(), local.toLocalTime(), "the same local time every day");
            }
        }
    }

    @Property
    void aMonthlyRuleOnADayThatSomeMonthsLackSkipsThoseMonthsInsteadOfClamping(
            @ForAll @IntRange(min = 29, max = 31) int day,
            @ForAll("zones") ZoneId zone,
            @ForAll("starts") LocalDateTime start) {
        Schedule monthly = new Schedule("MONTHLY", 1, List.of(), day);

        for (Instant occurrence : chain(monthly, zone, at(start, zone), null)) {
            LocalDate local = occurrence.atZone(zone).toLocalDate();
            assertEquals(day, local.getDayOfMonth());
            assertTrue(local.lengthOfMonth() >= day);
        }
    }

    @Property
    void anEndDateBeforeTheNextOccurrenceMeansThereIsNone(
            @ForAll("schedules") Schedule schedule,
            @ForAll("zones") ZoneId zone,
            @ForAll("starts") LocalDateTime start) {
        Instant startsAt = at(start, zone);

        Optional<Instant> unbounded =
                RruleEngine.nextOccurrence(
                        schedule.rrule(), zone, startsAt, null, startsAt.minusSeconds(1));
        if (unbounded.isEmpty()) {
            return;
        }
        Instant first = unbounded.get();

        assertTrue(
                RruleEngine.nextOccurrence(
                                schedule.rrule(),
                                zone,
                                startsAt,
                                first.minusSeconds(1),
                                startsAt.minusSeconds(1))
                        .isEmpty());
        assertEquals(
                Optional.of(first),
                RruleEngine.nextOccurrence(
                        schedule.rrule(), zone, startsAt, first, startsAt.minusSeconds(1)));
    }

    @ParameterizedTest
    @ValueSource(
            strings = {
                "",
                "INTERVAL=2",
                "FREQ=YEARLY",
                "FREQ=DAILY;INTERVAL=0",
                "FREQ=DAILY;INTERVAL=x",
                "FREQ=WEEKLY;BYDAY=XX",
                "FREQ=MONTHLY;BYMONTHDAY=0",
                "FREQ=MONTHLY;BYMONTHDAY=32",
                "FREQ=MONTHLY;BYMONTHDAY=abc",
                "FREQ"
            })
    void aRuleThatIsMissingOrInvalidIsRefused(String rrule) {
        Instant start = Instant.parse("2026-03-01T09:00:00Z");

        assertThrows(
                TaskException.BadRequest.class,
                () -> RruleEngine.nextOccurrence(rrule, ZoneId.of("UTC"), start, null, start));
    }
}
