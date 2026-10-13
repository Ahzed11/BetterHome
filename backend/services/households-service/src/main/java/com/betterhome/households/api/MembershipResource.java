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
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/v1/households/{householdId}/members")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "memberships")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class MembershipResource {

    private final MembershipService membershipService;

    @Inject
    public MembershipResource(MembershipService membershipService) {
        this.membershipService = membershipService;
    }

    @Operation(operationId = "listMembers", summary = "List active members")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = MembershipResponse.class)))
    @GET
    public List<MembershipResponse> list(@PathParam("householdId") UUID householdId) {
        return membershipService.list(householdId).stream().map(MembershipResponse::from).toList();
    }

    @Operation(operationId = "changeMemberRole", summary = "Change a member role (admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = MembershipResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
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

    @Operation(operationId = "leaveHousehold", summary = "Leave the household")
    @APIResponse(responseCode = "204", description = "Left")
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/me/leave")
    public Response leave(@PathParam("householdId") UUID householdId) {
        membershipService.leave(householdId);
        return Response.noContent().build();
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = MembershipResponse.class)))
    @Operation(
            operationId = "setMemberAway",
            summary = "Mark a member away and dismiss their open tasks (admin)")
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "503",
            description = "tasks-service unavailable; nothing was saved",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
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

    @Operation(operationId = "clearMemberAway", summary = "Clear away status (admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = MembershipResponse.class)))
    @DELETE
    @Path("/{userId}/away")
    public MembershipResponse clearAway(
            @PathParam("householdId") UUID householdId, @PathParam("userId") UUID userId) {
        return MembershipResponse.from(membershipService.clearAway(householdId, userId));
    }
}
