package com.betterhome.lists.api;

import com.betterhome.lists.api.ListDtos.AnonymizationResponse;
import com.betterhome.lists.service.AnonymizationService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.POST;
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

/** Account-deletion hook for other BetterHome services (the {@code service} realm role only). */
@Path("/v1/internal/users")
@RolesAllowed("service")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "internal")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(responseCode = "403", description = "Not allowed to do this")
public class InternalUserResource {

    private final AnonymizationService anonymizationService;

    @Inject
    public InternalUserResource(AnonymizationService anonymizationService) {
        this.anonymizationService = anonymizationService;
    }

    @Operation(
            operationId = "anonymizeUser",
            summary =
                    "Replace a deleted user's id on every list and item with the anonymous id;"
                            + " repeating it or naming an unknown user changes nothing (service"
                            + " role)")
    @APIResponse(
            responseCode = "200",
            description = "Rows changed per column, all zero when nothing was left to change",
            content = @Content(schema = @Schema(implementation = AnonymizationResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/{userId}/anonymize")
    public AnonymizationResponse anonymize(@PathParam("userId") UUID userId) {
        return AnonymizationResponse.from(anonymizationService.anonymize(userId));
    }
}
