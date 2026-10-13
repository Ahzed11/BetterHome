package com.betterhome.households.api;

import com.betterhome.households.api.HouseholdDtos.ChangeRoleRequest;
import com.betterhome.households.api.HouseholdDtos.MembershipResponse;
import com.betterhome.households.api.HouseholdDtos.SetAwayRequest;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.service.MembershipService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.List;
import java.util.UUID;

@Path("/v1/households/{householdId}/members")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MembershipResource {

    private final MembershipService membershipService;

    @Inject
    public MembershipResource(MembershipService membershipService) {
        this.membershipService = membershipService;
    }

    @GET
    public List<MembershipResponse> list(@PathParam("householdId") UUID householdId) {
        return membershipService.list(householdId).stream().map(MembershipResponse::from).toList();
    }

    @PATCH
    @Path("/{userId}/role")
    public MembershipResponse changeRole(
            @PathParam("householdId") UUID householdId,
            @PathParam("userId") UUID userId,
            ChangeRoleRequest request) {
        if (request == null || request.role() == null) {
            throw new HouseholdException.BadRequest("role is required");
        }
        return MembershipResponse.from(
                membershipService.changeRole(householdId, userId, request.role()));
    }

    @POST
    @Path("/me/leave")
    public Response leave(@PathParam("householdId") UUID householdId) {
        membershipService.leave(householdId);
        return Response.noContent().build();
    }

    @POST
    @Path("/{userId}/away")
    public MembershipResponse setAway(
            @PathParam("householdId") UUID householdId,
            @PathParam("userId") UUID userId,
            SetAwayRequest request) {
        return MembershipResponse.from(
                membershipService.setAway(
                        householdId,
                        userId,
                        request == null ? null : request.awayFrom(),
                        request == null ? null : request.awayUntil()));
    }

    @DELETE
    @Path("/{userId}/away")
    public MembershipResponse clearAway(
            @PathParam("householdId") UUID householdId, @PathParam("userId") UUID userId) {
        return MembershipResponse.from(membershipService.clearAway(householdId, userId));
    }
}
