package com.betterhome.households.api;

import com.betterhome.households.api.HouseholdDtos.MembershipResponse;
import com.betterhome.households.service.InvitationService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/**
 * Kept apart from {@link InvitationResource}: a class rooted at {@code /v1} loses to {@code
 * HouseholdResource} at {@code /v1/households}, which made invitation routes answer 404.
 */
@Path("/v1/invitations/{token}/accept")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "invitations")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class InvitationAcceptResource {

    private final InvitationService invitationService;

    @Inject
    public InvitationAcceptResource(InvitationService invitationService) {
        this.invitationService = invitationService;
    }

    @Operation(operationId = "acceptInvitation", summary = "Accept an invitation with its token")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = MembershipResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    public MembershipResponse accept(@PathParam("token") String token) {
        return MembershipResponse.from(invitationService.accept(token));
    }
}
