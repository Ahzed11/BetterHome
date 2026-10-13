package com.betterhome.households.api;

import com.betterhome.households.api.HouseholdDtos.MembershipResponse;
import com.betterhome.households.service.InvitationService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

/**
 * Kept apart from {@link InvitationResource}: a class rooted at {@code /v1} loses to {@code
 * HouseholdResource} at {@code /v1/households}, which made invitation routes answer 404.
 */
@Path("/v1/invitations/{token}/accept")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class InvitationAcceptResource {

    private final InvitationService invitationService;

    @Inject
    public InvitationAcceptResource(InvitationService invitationService) {
        this.invitationService = invitationService;
    }

    @POST
    public MembershipResponse accept(@PathParam("token") String token) {
        return MembershipResponse.from(invitationService.accept(token));
    }
}
