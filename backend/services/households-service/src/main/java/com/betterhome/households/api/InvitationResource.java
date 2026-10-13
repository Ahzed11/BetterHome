package com.betterhome.households.api;

import com.betterhome.households.api.HouseholdDtos.MembershipResponse;
import com.betterhome.households.api.InvitationDtos.CreateInvitationRequest;
import com.betterhome.households.api.InvitationDtos.InvitationResponse;
import com.betterhome.households.service.InvitationService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.List;
import java.util.UUID;

@Path("/v1")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class InvitationResource {

    private final InvitationService invitationService;

    @Inject
    public InvitationResource(InvitationService invitationService) {
        this.invitationService = invitationService;
    }

    @POST
    @Path("/households/{householdId}/invitations")
    public Response create(
            @PathParam("householdId") UUID householdId, @Valid CreateInvitationRequest request) {
        InvitationResponse body =
                InvitationResponse.from(
                        invitationService.create(householdId, request.email(), request.role()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @GET
    @Path("/households/{householdId}/invitations")
    public List<InvitationResponse> listPending(@PathParam("householdId") UUID householdId) {
        return invitationService.listPending(householdId).stream()
                .map(InvitationResponse::from)
                .toList();
    }

    @POST
    @Path("/invitations/{token}/accept")
    public MembershipResponse accept(@PathParam("token") String token) {
        return MembershipResponse.from(invitationService.accept(token));
    }
}
