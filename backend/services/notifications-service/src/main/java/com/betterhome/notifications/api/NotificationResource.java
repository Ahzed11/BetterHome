package com.betterhome.notifications.api;

import com.betterhome.notifications.api.NotificationDtos.NotificationResponse;
import com.betterhome.notifications.api.NotificationDtos.ReadAllResponse;
import com.betterhome.notifications.service.CallerService;
import com.betterhome.notifications.service.InboxService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/** The caller's own notifications. Nothing here accepts a user id: the token decides. */
@Path("/v1/notifications")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "notifications")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "503",
        description = "A service this one depends on is unavailable",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class NotificationResource {

    private final CallerService callerService;
    private final InboxService inboxService;

    @Inject
    public NotificationResource(CallerService callerService, InboxService inboxService) {
        this.callerService = callerService;
        this.inboxService = inboxService;
    }

    @Operation(
            operationId = "listMyNotifications",
            summary = "My inbox, newest first; page with before=<id of the last item>")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = NotificationResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @GET
    public List<NotificationResponse> list(
            @QueryParam("householdId") UUID householdId,
            @DefaultValue("false") @QueryParam("unreadOnly") boolean unreadOnly,
            @DefaultValue("50") @QueryParam("limit") int limit,
            @QueryParam("before") UUID before) {
        UUID userId = callerService.requireUserId();
        return inboxService
                .list(
                        userId,
                        Optional.ofNullable(householdId),
                        unreadOnly,
                        Optional.ofNullable(before),
                        limit)
                .stream()
                .map(NotificationResponse::from)
                .toList();
    }

    @Operation(
            operationId = "markMyNotificationRead",
            summary = "Mark one of my notifications read")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = NotificationResponse.class)))
    @APIResponse(
            responseCode = "404",
            description = "Not found",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/{notificationId}/read")
    public NotificationResponse markRead(@PathParam("notificationId") UUID notificationId) {
        UUID userId = callerService.requireUserId();
        return NotificationResponse.from(inboxService.markRead(userId, notificationId));
    }

    @Operation(
            operationId = "markAllMyNotificationsRead",
            summary = "Mark all my unread notifications read, optionally for one household")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ReadAllResponse.class)))
    @POST
    @Path("/read-all")
    public ReadAllResponse markAllRead(@QueryParam("householdId") UUID householdId) {
        UUID userId = callerService.requireUserId();
        return new ReadAllResponse(
                inboxService.markAllRead(userId, Optional.ofNullable(householdId)));
    }
}
