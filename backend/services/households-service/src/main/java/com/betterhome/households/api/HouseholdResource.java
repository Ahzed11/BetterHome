package com.betterhome.households.api;

import com.betterhome.households.api.HouseholdDtos.CreateHouseholdRequest;
import com.betterhome.households.api.HouseholdDtos.HouseholdResponse;
import com.betterhome.households.api.HouseholdDtos.UpdateHouseholdRequest;
import com.betterhome.households.service.HouseholdService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
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

@Path("/v1/households")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "households")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class HouseholdResource {

    private final HouseholdService householdService;

    @Inject
    public HouseholdResource(HouseholdService householdService) {
        this.householdService = householdService;
    }

    @Operation(
            operationId = "createHousehold",
            summary = "Create a household; the caller becomes its first admin")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = HouseholdResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    public Response create(@Valid CreateHouseholdRequest request) {
        HouseholdResponse body =
                HouseholdResponse.from(householdService.create(request.name(), request.timezone()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = HouseholdResponse.class)))
    @Operation(
            operationId = "listMyHouseholds",
            summary = "List the households the caller belongs to")
    @GET
    public List<HouseholdResponse> listMine() {
        return householdService.listMine().stream().map(HouseholdResponse::from).toList();
    }

    @Operation(operationId = "getHousehold", summary = "Get a household")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = HouseholdResponse.class)))
    @GET
    @Path("/{householdId}")
    public HouseholdResponse get(@PathParam("householdId") UUID householdId) {
        return HouseholdResponse.from(householdService.get(householdId));
    }

    @Operation(operationId = "updateHousehold", summary = "Update household settings (admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = HouseholdResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @PATCH
    @Path("/{householdId}")
    public HouseholdResponse update(
            @PathParam("householdId") UUID householdId, UpdateHouseholdRequest request) {
        return HouseholdResponse.from(
                householdService.update(
                        householdId,
                        request.name(),
                        request.timezone(),
                        request.reminderDaysBefore(),
                        request.reminderTime()));
    }

    @Operation(operationId = "deleteHousehold", summary = "Delete a household (admin)")
    @APIResponse(responseCode = "204", description = "Deleted")
    @DELETE
    @Path("/{householdId}")
    public Response delete(@PathParam("householdId") UUID householdId) {
        householdService.delete(householdId);
        return Response.noContent().build();
    }
}
