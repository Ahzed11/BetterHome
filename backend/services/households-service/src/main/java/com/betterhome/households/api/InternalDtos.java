package com.betterhome.households.api;

import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.MembershipRole;
import java.time.Instant;
import java.time.LocalTime;
import java.util.UUID;

/** Payloads for service-to-service calls (see {@link InternalHouseholdResource}). */
public final class InternalDtos {

    private InternalDtos() {}

    public record InternalMemberResponse(
            UUID userId, UUID authSubject, MembershipRole role, boolean away, Instant joinedAt) {}

    public record InternalSettingsResponse(
            String timezone, int reminderDaysBefore, LocalTime reminderTime) {

        public static InternalSettingsResponse from(Household household) {
            return new InternalSettingsResponse(
                    household.timezone, household.reminderDaysBefore, household.reminderTime);
        }
    }
}
