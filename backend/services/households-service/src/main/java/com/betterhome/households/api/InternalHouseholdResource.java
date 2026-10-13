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

/** Read-only endpoints for service accounts (the {@code service} realm role). */
@Path("/v1/internal/households/{householdId}")
@RolesAllowed("service")
@Produces(MediaType.APPLICATION_JSON)
public class InternalHouseholdResource {

    private final InternalHouseholdService internalHouseholdService;

    @Inject
    public InternalHouseholdResource(InternalHouseholdService internalHouseholdService) {
        this.internalHouseholdService = internalHouseholdService;
    }

    @GET
    @Path("/members")
    public List<InternalMemberResponse> members(@PathParam("householdId") UUID householdId) {
        return internalHouseholdService.listMembers(householdId);
    }

    @GET
    @Path("/settings")
    public InternalSettingsResponse settings(@PathParam("householdId") UUID householdId) {
        return internalHouseholdService.settings(householdId);
    }
}
