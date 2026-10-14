package com.betterhome.notifications.api;

import com.betterhome.notifications.api.NotificationDtos.IngestRequest;
import com.betterhome.notifications.api.NotificationDtos.IngestResponse;
import com.betterhome.notifications.api.NotificationDtos.NotificationResponse;
import com.betterhome.notifications.service.IngestService;
import com.betterhome.notifications.service.IngestService.Outcome;
import com.betterhome.notifications.service.IngestService.Result;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/** Event ingest for other BetterHome services (the {@code service} realm role only). */
@Path("/v1/internal/notifications")
@RolesAllowed("service")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "internal")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(responseCode = "403", description = "Not allowed to do this")
@APIResponse(
        responseCode = "503",
        description = "A service this one depends on is unavailable",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class InternalNotificationResource {

    private final IngestService ingestService;

    @Inject
    public InternalNotificationResource(IngestService ingestService) {
        this.ingestService = ingestService;
    }

    @Operation(
            operationId = "ingestNotificationEvent",
            summary =
                    "Turn an event into notifications for its recipient; repeating an"
                            + " idempotency key changes nothing (service role)")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = IngestResponse.class)))
    @APIResponse(
            responseCode = "200",
            description = "Already stored or switched off by the recipient",
            content = @Content(schema = @Schema(implementation = IngestResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    public Response ingest(@Valid IngestRequest request) {
        Result result =
                ingestService.ingest(
                        new IngestService.Event(
                                request.idempotencyKey(),
                                request.householdId(),
                                request.userId(),
                                request.type(),
                                request.payload(),
                                request.localeHint()));
        IngestResponse body =
                new IngestResponse(
                        result.outcome(),
                        result.notification().map(NotificationResponse::from).orElse(null));
        int status = result.outcome() == Outcome.created ? 201 : 200;
        return Response.status(status).entity(body).build();
    }
}
