package com.betterhome.notifications.api;

import com.betterhome.notifications.api.NotificationDtos.NotificationsAnonymizationResponse;
import com.betterhome.notifications.service.AnonymizationService;
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
                    "Delete a deleted user's notifications and preferences; repeating it or naming"
                            + " an unknown user changes nothing (service role)")
    @APIResponse(
            responseCode = "200",
            description = "Rows deleted per kind, all zero when nothing was left to delete",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            implementation =
                                                    NotificationsAnonymizationResponse.class)))
    @POST
    @Path("/{userId}/anonymize")
    public NotificationsAnonymizationResponse anonymize(@PathParam("userId") UUID userId) {
        return NotificationsAnonymizationResponse.from(anonymizationService.anonymize(userId));
    }
}
