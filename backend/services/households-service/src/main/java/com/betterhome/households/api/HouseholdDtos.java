package com.betterhome.households.api;

import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import java.time.LocalTime;
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
            @Schema(type = SchemaType.STRING, format = "time", example = "08:00:00")
                    LocalTime reminderTime) {}

    public record HouseholdResponse(
            UUID id,
            String name,
            String timezone,
            int reminderDaysBefore,
            @Schema(type = SchemaType.STRING, format = "time", example = "08:00:00")
                    LocalTime reminderTime,
            UUID createdBy) {

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
            UUID id,
            UUID userId,
            UUID householdId,
            MembershipRole role,
            Instant joinedAt,
            Instant awayFrom,
            Instant awayUntil,
            UUID awaySetBy) {

        public static MembershipResponse from(Membership membership) {
            return new MembershipResponse(
                    membership.id,
                    membership.userId,
                    membership.householdId,
                    membership.role,
                    membership.joinedAt,
                    membership.awayFrom,
                    membership.awayUntil,
                    membership.awaySetBy);
        }
    }

    public record ChangeRoleRequest(MembershipRole role) {}

    public record SetAwayRequest(Instant awayFrom, Instant awayUntil) {}
}
