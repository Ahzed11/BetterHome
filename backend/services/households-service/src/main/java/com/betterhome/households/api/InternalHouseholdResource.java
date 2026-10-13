package com.betterhome.households.api;

import com.betterhome.households.api.InternalDtos.InternalMemberResponse;
import com.betterhome.households.api.InternalDtos.InternalSettingsResponse;
import com.betterhome.households.service.InternalHouseholdService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.util.List;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/** Read-only endpoints for service accounts (the {@code service} realm role). */
@Path("/v1/internal/households/{householdId}")
@RolesAllowed("service")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "internal")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(responseCode = "403", description = "Not allowed to do this")
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class InternalHouseholdResource {

    private final InternalHouseholdService internalHouseholdService;

    @Inject
    public InternalHouseholdResource(InternalHouseholdService internalHouseholdService) {
        this.internalHouseholdService = internalHouseholdService;
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = InternalMemberResponse.class)))
    @Operation(
            operationId = "listHouseholdMembersInternal",
            summary = "Active members in joining order, with away resolved now (service role)")
    @GET
    @Path("/members")
    public List<InternalMemberResponse> members(@PathParam("householdId") UUID householdId) {
        return internalHouseholdService.listMembers(householdId);
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = InternalSettingsResponse.class)))
    @Operation(
            operationId = "getHouseholdSettingsInternal",
            summary = "Timezone and reminder settings (service role)")
    @GET
    @Path("/settings")
    public InternalSettingsResponse settings(@PathParam("householdId") UUID householdId) {
        return internalHouseholdService.settings(householdId);
    }
}
