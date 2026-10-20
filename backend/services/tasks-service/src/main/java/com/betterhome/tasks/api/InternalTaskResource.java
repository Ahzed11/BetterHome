package com.betterhome.tasks.api;

import com.betterhome.tasks.api.TaskDtos.DismissedCount;
import com.betterhome.tasks.service.TaskService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.constraints.NotNull;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/** Write endpoints for service accounts (the {@code service} realm role). */
@Path("/v1/internal/households/{householdId}/tasks")
@RolesAllowed("service")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "internal")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(responseCode = "403", description = "Not allowed to do this")
public class InternalTaskResource {

    private final TaskService taskService;

    @Inject
    public InternalTaskResource(TaskService taskService) {
        this.taskService = taskService;
    }

    @Operation(
            operationId = "dismissAwayMemberTasksInternal",
            summary = "Dismiss the open tasks of a member whose away period started (service role)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = DismissedCount.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/dismiss-away/{userId}")
    public DismissedCount dismissAway(
            @PathParam("householdId") UUID householdId,
            @PathParam("userId") UUID userId,
            @QueryParam("dismissedBy") @NotNull UUID dismissedBy) {
        return new DismissedCount(
                taskService.dismissOpenTasksForAwayMemberAsService(
                        householdId, userId, dismissedBy));
    }
}
