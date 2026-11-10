package com.betterhome.households.service;

import com.betterhome.households.domain.HouseholdException;
import java.time.DateTimeException;
import java.time.ZoneId;

/** Validates time zone names at the boundary, with the same parser the recurrence engine uses. */
final class TimeZones {

    private TimeZones() {}

    /** Returns the trimmed zone id, or throws a 400 when {@link ZoneId#of} cannot parse it. */
    static String require(String timezone) {
        String trimmed = timezone.trim();
        try {
            ZoneId.of(trimmed);
        } catch (DateTimeException e) {
            throw new HouseholdException.BadRequest(
                    "timezone is not a valid time zone: " + trimmed);
        }
        return trimmed;
    }
}
