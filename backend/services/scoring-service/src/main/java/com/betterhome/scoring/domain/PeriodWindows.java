package com.betterhome.scoring.domain;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;

/**
 * The time windows of the scoreboard, in the household's timezone (spec §3.4): a week starts on
 * Monday at local midnight, a month and a year at the local midnight of their first day. A window
 * is {@code [from, to)}, so an instant exactly on a boundary belongs to the window that starts
 * there. Local midnights are resolved by {@link java.time.ZonedDateTime} rules, so daylight saving
 * changes make a window a day or an hour longer or shorter but never leave a gap or an overlap.
 */
public final class PeriodWindows {

    /** A half-open window; {@code from} and {@code to} are null for all time. */
    public record Window(Instant from, Instant to, String label) {}

    private PeriodWindows() {}

    /**
     * The window of {@code period} that contains {@code now}; for {@link ScorePeriod#month} the
     * given {@code month} instead when it is not null (browsing a past month).
     */
    public static Window of(ScorePeriod period, ZoneId zone, Instant now, YearMonth month) {
        LocalDate today = LocalDate.ofInstant(now, zone);
        return switch (period) {
            case all -> new Window(null, null, null);
            case week -> {
                LocalDate monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
                yield new Window(startOf(monday, zone), startOf(monday.plusWeeks(1), zone), null);
            }
            case month -> month(month == null ? YearMonth.from(today) : month, zone);
            case year ->
                    new Window(
                            startOf(LocalDate.of(today.getYear(), 1, 1), zone),
                            startOf(LocalDate.of(today.getYear() + 1, 1, 1), zone),
                            String.valueOf(today.getYear()));
        };
    }

    public static Window month(YearMonth month, ZoneId zone) {
        return new Window(
                startOf(month.atDay(1), zone),
                startOf(month.plusMonths(1).atDay(1), zone),
                month.toString());
    }

    /** The month an instant falls in, in the given zone. */
    public static YearMonth monthOf(Instant instant, ZoneId zone) {
        return YearMonth.from(LocalDate.ofInstant(instant, zone));
    }

    /** When the month ends: the first instant of the next one. */
    public static Instant endOfMonth(YearMonth month, ZoneId zone) {
        return month(month, zone).to();
    }

    private static Instant startOf(LocalDate day, ZoneId zone) {
        return day.atStartOfDay(zone).toInstant();
    }
}
