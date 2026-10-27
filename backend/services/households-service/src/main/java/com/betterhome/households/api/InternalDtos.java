package com.betterhome.households.api;

import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.MembershipRole;
import java.time.Instant;
import java.time.LocalTime;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/** Payloads for service-to-service calls (see {@link InternalHouseholdResource}). */
public final class InternalDtos {

    private InternalDtos() {}

    public record InternalMemberResponse(
            @Schema(required = true) UUID userId,
            @Schema(required = true) UUID authSubject,
            @Schema(required = true) MembershipRole role,
            @Schema(required = true) boolean away,
            @Schema(required = true) Instant joinedAt) {}

    /** Who a user is for other services: our id, the token subject and the display language. */
    public record InternalUserResponse(
            @Schema(required = true) UUID userId,
            @Schema(required = true) UUID authSubject,
            @Schema(required = true) String language) {

        public static InternalUserResponse from(AppUser user) {
            return new InternalUserResponse(user.id, user.authSubject, user.language);
        }
    }

    public record InternalSettingsResponse(
            @Schema(required = true) String timezone,
            @Schema(required = true) int reminderDaysBefore,
            @Schema(
                            required = true,
                            type = SchemaType.STRING,
                            format = "partial-time",
                            pattern = "^([01]\\d|2[0-3]):[0-5]\\d(:[0-5]\\d)?$",
                            example = "08:00:00")
                    LocalTime reminderTime) {

        public static InternalSettingsResponse from(Household household) {
            return new InternalSettingsResponse(
                    household.timezone, household.reminderDaysBefore, household.reminderTime);
        }
    }
}
