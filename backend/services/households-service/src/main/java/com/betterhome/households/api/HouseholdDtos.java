package com.betterhome.households.api;

import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import java.time.LocalTime;
import java.util.Optional;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

public final class HouseholdDtos {

    private HouseholdDtos() {}

    public record CreateHouseholdRequest(@NotBlank String name, @NotBlank String timezone) {}

    public record UpdateHouseholdRequest(
            String name,
            String timezone,
            Integer reminderDaysBefore,
            @Schema(
                            type = SchemaType.STRING,
                            format = "partial-time",
                            pattern = "^([01]\\d|2[0-3]):[0-5]\\d(:[0-5]\\d)?$",
                            example = "08:00:00")
                    LocalTime reminderTime) {}

    public record HouseholdResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) String name,
            @Schema(required = true) String timezone,
            @Schema(required = true) int reminderDaysBefore,
            @Schema(
                            required = true,
                            type = SchemaType.STRING,
                            format = "partial-time",
                            pattern = "^([01]\\d|2[0-3]):[0-5]\\d(:[0-5]\\d)?$",
                            example = "08:00:00")
                    LocalTime reminderTime,
            @Schema(required = true) UUID createdBy) {

        public static HouseholdResponse from(Household household) {
            return new HouseholdResponse(
                    household.id,
                    household.name,
                    household.timezone,
                    household.reminderDaysBefore,
                    household.reminderTime,
                    household.createdBy);
        }
    }

    public record MembershipResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID userId,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) MembershipRole role,
            @Schema(required = true) Instant joinedAt,
            Instant awayFrom,
            Instant awayUntil,
            UUID awaySetBy,
            String givenName,
            String familyName) {

        /**
         * Names let household members tell each other apart; absent once the account is deleted.
         */
        public static MembershipResponse from(Membership membership) {
            Optional<AppUser> user = AppUser.findActiveById(membership.userId);
            return new MembershipResponse(
                    membership.id,
                    membership.userId,
                    membership.householdId,
                    membership.role,
                    membership.joinedAt,
                    membership.awayFrom,
                    membership.awayUntil,
                    membership.awaySetBy,
                    user.map(u -> u.givenName).orElse(null),
                    user.map(u -> u.familyName).orElse(null));
        }
    }

    public record ChangeRoleRequest(MembershipRole role) {}

    public record SetAwayRequest(Instant awayFrom, Instant awayUntil) {}
}
