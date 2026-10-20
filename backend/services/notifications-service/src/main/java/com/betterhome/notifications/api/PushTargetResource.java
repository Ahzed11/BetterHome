package com.betterhome.notifications.api;

import com.betterhome.notifications.api.NotificationDtos.PushTargetResponse;
import com.betterhome.notifications.api.NotificationDtos.RegisterPushTargetRequest;
import com.betterhome.notifications.domain.NotificationException;
import com.betterhome.notifications.service.CallerService;
import com.betterhome.notifications.service.PushTargetService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/**
 * The caller's own push target: the Gotify application token pushes are sent with (ADR 0027). One
 * per user. The token is only ever written here, never read back.
 */
@Path("/v1/push-target")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "push")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "503",
        description = "A service this one depends on is unavailable",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class PushTargetResource {

    private final CallerService callerService;
    private final PushTargetService pushTargetService;

    @Inject
    public PushTargetResource(CallerService callerService, PushTargetService pushTargetService) {
        this.callerService = callerService;
        this.pushTargetService = pushTargetService;
    }

    @Operation(
            operationId = "registerMyPushTarget",
            summary = "Register my Gotify application token, replacing the previous one")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = PushTargetResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @PUT
    public PushTargetResponse register(@Valid RegisterPushTargetRequest request) {
        return PushTargetResponse.from(
                pushTargetService.register(callerService.requireUserId(), request.token()));
    }

    @Operation(operationId = "getMyPushTarget", summary = "Whether I have a push target")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = PushTargetResponse.class)))
    @APIResponse(
            responseCode = "404",
            description = "No push target",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @GET
    public PushTargetResponse get() {
        return pushTargetService
                .find(callerService.requireUserId())
                .map(PushTargetResponse::from)
                .orElseThrow(() -> new NotificationException.NotFound("No push target"));
    }

    @Operation(
            operationId = "removeMyPushTarget",
            summary = "Remove my push target; pushes stop, the inbox is unaffected")
    @APIResponse(responseCode = "204", description = "Removed, or there was none")
    @DELETE
    public Response remove() {
        pushTargetService.remove(callerService.requireUserId());
        return Response.noContent().build();
    }
}
