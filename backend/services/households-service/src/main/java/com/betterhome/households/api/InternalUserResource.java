package com.betterhome.households.api;

import com.betterhome.households.api.InternalDtos.InternalUserResponse;
import com.betterhome.households.service.InternalHouseholdService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/** Read-only user lookups for service accounts (the {@code service} realm role). */
@Path("/v1/internal/users")
@RolesAllowed("service")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "internal")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(responseCode = "403", description = "Not allowed to do this")
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class InternalUserResource {

    private final InternalHouseholdService internalHouseholdService;

    @Inject
    public InternalUserResource(InternalHouseholdService internalHouseholdService) {
        this.internalHouseholdService = internalHouseholdService;
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = InternalUserResponse.class)))
    @Operation(
            operationId = "getUserInternal",
            summary = "Language and token subject of a user by our user id (service role)")
    @GET
    @Path("/{userId}")
    public InternalUserResponse byId(@PathParam("userId") UUID userId) {
        return internalHouseholdService.userById(userId);
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = InternalUserResponse.class)))
    @Operation(
            operationId = "getUserBySubjectInternal",
            summary = "Our user id and language for a verified token subject (service role)")
    @GET
    @Path("/by-subject/{authSubject}")
    public InternalUserResponse bySubject(@PathParam("authSubject") UUID authSubject) {
        return internalHouseholdService.userByAuthSubject(authSubject);
    }
}
