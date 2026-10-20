package com.betterhome.tasks.domain;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * Minimal RRULE evaluator for daily / weekly / monthly schedules in a household timezone (incl.
 * DST). Supports {@code FREQ}, {@code INTERVAL}, {@code BYDAY}, {@code BYMONTHDAY}.
 */
public final class RruleEngine {

    private RruleEngine() {}

    /**
     * Next occurrence strictly after {@code afterExclusive}, not before {@code startsAt}, and not
     * after {@code endsAt} when set.
     */
    public static Optional<Instant> nextOccurrence(
            String rrule, ZoneId zone, Instant startsAt, Instant endsAt, Instant afterExclusive) {
        ParsedRule rule = ParsedRule.parse(rrule);
        LocalTime timeOfDay = startsAt.atZone(zone).toLocalTime();
        LocalDate startDate = startsAt.atZone(zone).toLocalDate();

        LocalDate day = afterExclusive.atZone(zone).toLocalDate();
        ZonedDateTime afterZoned = afterExclusive.atZone(zone);
        if (!afterZoned.toLocalTime().isBefore(timeOfDay)) {
            day = day.plusDays(1);
        }
        if (day.isBefore(startDate)) {
            day = startDate;
        }

        for (int i = 0; i < 5000; i++) {
            if (matches(rule, startDate, day)) {
                Instant occurrence = occurrenceOn(day, timeOfDay, zone);
                if (!occurrence.isAfter(afterExclusive)) {
                    day = day.plusDays(1);
                    continue;
                }
                if (occurrence.isBefore(startsAt)) {
                    day = day.plusDays(1);
                    continue;
                }
                if (endsAt != null && occurrence.isAfter(endsAt)) {
                    return Optional.empty();
                }
                return Optional.of(occurrence);
            }
            day = day.plusDays(1);
            if (endsAt != null
                    && day.atStartOfDay(zone)
                            .toInstant()
                            .isAfter(endsAt.plus(40, ChronoUnit.DAYS))) {
                break;
            }
        }
        return Optional.empty();
    }

    /**
     * The instant of {@code timeOfDay} on {@code day}. A time that does not exist (daylight saving
     * gap) moves forward by the length of the gap, except when that would land on the next calendar
     * day: the occurrence then stays on {@code day}, at its last second.
     */
    private static Instant occurrenceOn(LocalDate day, LocalTime timeOfDay, ZoneId zone) {
        ZonedDateTime resolved = day.atTime(timeOfDay).atZone(zone);
        if (resolved.toLocalDate().equals(day)) {
            return resolved.toInstant();
        }
        return day.plusDays(1).atStartOfDay(zone).toInstant().minusSeconds(1);
    }

    private static boolean matches(ParsedRule rule, LocalDate startDate, LocalDate date) {
        return switch (rule.freq) {
            case DAILY -> {
                long days = ChronoUnit.DAYS.between(startDate, date);
                yield days >= 0 && days % rule.interval == 0;
            }
            case WEEKLY -> {
                if (!rule.byDay.isEmpty() && !rule.byDay.contains(date.getDayOfWeek())) {
                    yield false;
                }
                if (rule.byDay.isEmpty() && date.getDayOfWeek() != startDate.getDayOfWeek()) {
                    yield false;
                }
                LocalDate weekStart =
                        startDate.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
                LocalDate candWeek = date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
                long weeks = ChronoUnit.WEEKS.between(weekStart, candWeek);
                yield weeks >= 0 && weeks % rule.interval == 0;
            }
            case MONTHLY -> {
                int day = rule.byMonthDay != null ? rule.byMonthDay : startDate.getDayOfMonth();
                if (day > date.lengthOfMonth() || date.getDayOfMonth() != day) {
                    yield false;
                }
                long months =
                        ChronoUnit.MONTHS.between(
                                startDate.withDayOfMonth(1), date.withDayOfMonth(1));
                yield months >= 0 && months % rule.interval == 0;
            }
        };
    }

    private enum Freq {
        DAILY,
        WEEKLY,
        MONTHLY
    }

    private record ParsedRule(Freq freq, int interval, Set<DayOfWeek> byDay, Integer byMonthDay) {

        static ParsedRule parse(String rrule) {
            if (rrule == null || rrule.isBlank()) {
                throw new TaskException.BadRequest("rrule is required");
            }
            String normalized = rrule.trim();
            if (normalized.toUpperCase(Locale.ROOT).startsWith("RRULE:")) {
                normalized = normalized.substring(6);
            }
            Map<String, String> parts = new HashMap<>();
            for (String part : normalized.split(";")) {
                if (part.isBlank()) {
                    continue;
                }
                String[] kv = part.split("=", 2);
                if (kv.length != 2) {
                    throw new TaskException.BadRequest("Invalid RRULE part: " + part);
                }
                parts.put(kv[0].trim().toUpperCase(Locale.ROOT), kv[1].trim());
            }
            String freqRaw = parts.get("FREQ");
            if (freqRaw == null) {
                throw new TaskException.BadRequest("RRULE FREQ is required");
            }
            Freq freq =
                    switch (freqRaw.toUpperCase(Locale.ROOT)) {
                        case "DAILY" -> Freq.DAILY;
                        case "WEEKLY" -> Freq.WEEKLY;
                        case "MONTHLY" -> Freq.MONTHLY;
                        default ->
                                throw new TaskException.BadRequest("Unsupported FREQ: " + freqRaw);
                    };
            int interval = 1;
            if (parts.containsKey("INTERVAL")) {
                try {
                    interval = Integer.parseInt(parts.get("INTERVAL"));
                } catch (NumberFormatException ex) {
                    throw new TaskException.BadRequest("Invalid INTERVAL");
                }
                if (interval < 1) {
                    throw new TaskException.BadRequest("INTERVAL must be >= 1");
                }
            }
            Set<DayOfWeek> byDay = EnumSet.noneOf(DayOfWeek.class);
            if (parts.containsKey("BYDAY")) {
                for (String token : parts.get("BYDAY").split(",")) {
                    if (!token.isBlank()) {
                        byDay.add(parseDay(token.trim()));
                    }
                }
            }
            Integer byMonthDay = null;
            if (parts.containsKey("BYMONTHDAY")) {
                try {
                    byMonthDay = Integer.parseInt(parts.get("BYMONTHDAY"));
                } catch (NumberFormatException ex) {
                    throw new TaskException.BadRequest("Invalid BYMONTHDAY");
                }
                if (byMonthDay < 1 || byMonthDay > 31) {
                    throw new TaskException.BadRequest("BYMONTHDAY out of range");
                }
            }
            return new ParsedRule(freq, interval, byDay, byMonthDay);
        }

        private static DayOfWeek parseDay(String token) {
            return switch (token.toUpperCase(Locale.ROOT)) {
                case "MO" -> DayOfWeek.MONDAY;
                case "TU" -> DayOfWeek.TUESDAY;
                case "WE" -> DayOfWeek.WEDNESDAY;
                case "TH" -> DayOfWeek.THURSDAY;
                case "FR" -> DayOfWeek.FRIDAY;
                case "SA" -> DayOfWeek.SATURDAY;
                case "SU" -> DayOfWeek.SUNDAY;
                default -> throw new TaskException.BadRequest("Invalid BYDAY: " + token);
            };
        }
    }
}
