package com.betterhome.notifications.api;

import com.betterhome.notifications.api.NotificationDtos.PreferenceResponse;
import com.betterhome.notifications.api.NotificationDtos.UpdatePreferenceRequest;
import com.betterhome.notifications.service.CallerService;
import com.betterhome.notifications.service.PreferenceService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/** The caller's own choices per notification type and channel. Everything is on by default. */
@Path("/v1/notification-preferences")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "preferences")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "503",
        description = "A service this one depends on is unavailable",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class PreferenceResource {

    private final CallerService callerService;
    private final PreferenceService preferenceService;

    @Inject
    public PreferenceResource(CallerService callerService, PreferenceService preferenceService) {
        this.callerService = callerService;
        this.preferenceService = preferenceService;
    }

    @Operation(
            operationId = "listMyNotificationPreferences",
            summary = "Every type and channel with my choice")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = PreferenceResponse.class)))
    @GET
    public List<PreferenceResponse> list() {
        return preferenceService.list(callerService.requireUserId()).stream()
                .map(PreferenceResponse::from)
                .toList();
    }

    @Operation(
            operationId = "updateMyNotificationPreference",
            summary = "Turn one type on or off for one channel")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = PreferenceResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @PUT
    @Path("/{type}/{channel}")
    public PreferenceResponse update(
            @PathParam("type") String type,
            @PathParam("channel") String channel,
            @Valid UpdatePreferenceRequest request) {
        return PreferenceResponse.from(
                preferenceService.set(
                        callerService.requireUserId(), type, channel, request.enabled()));
    }
}
