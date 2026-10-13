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

@Path("/v1/households")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class HouseholdResource {

    private final HouseholdService householdService;

    @Inject
    public HouseholdResource(HouseholdService householdService) {
        this.householdService = householdService;
    }

    @POST
    public Response create(@Valid CreateHouseholdRequest request) {
        HouseholdResponse body =
                HouseholdResponse.from(householdService.create(request.name(), request.timezone()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @GET
    public List<HouseholdResponse> listMine() {
        return householdService.listMine().stream().map(HouseholdResponse::from).toList();
    }

    @GET
    @Path("/{householdId}")
    public HouseholdResponse get(@PathParam("householdId") UUID householdId) {
        return HouseholdResponse.from(householdService.get(householdId));
    }

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

    @DELETE
    @Path("/{householdId}")
    public Response delete(@PathParam("householdId") UUID householdId) {
        householdService.delete(householdId);
        return Response.noContent().build();
    }
}
