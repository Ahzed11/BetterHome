package com.betterhome.households.api;

import com.betterhome.households.domain.Invitation;
import com.betterhome.households.domain.MembershipRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

public final class InvitationDtos {

    private InvitationDtos() {}

    public record CreateInvitationRequest(
            @NotBlank @Email String email, @NotNull MembershipRole role) {}

    public record InvitationResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) String email,
            @Schema(required = true) MembershipRole role,
            @Schema(required = true) String token,
            @Schema(required = true) Instant expiresAt,
            Instant acceptedAt) {

        public static InvitationResponse from(Invitation invitation) {
            return new InvitationResponse(
                    invitation.id,
                    invitation.householdId,
                    invitation.email,
                    invitation.role,
                    invitation.token,
                    invitation.expiresAt,
                    invitation.acceptedAt);
        }
    }
}
