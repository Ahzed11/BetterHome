package com.betterhome.tasks.api;

import com.betterhome.tasks.api.TaskDtos.CreateOpenTaskRequest;
import com.betterhome.tasks.api.TaskDtos.DismissedCount;
import com.betterhome.tasks.api.TaskDtos.QuickLogRequest;
import com.betterhome.tasks.api.TaskDtos.ReassignedCount;
import com.betterhome.tasks.api.TaskDtos.RevertRequest;
import com.betterhome.tasks.api.TaskDtos.TaskResponse;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.service.TaskService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.List;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/v1/households/{householdId}/tasks")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "tasks")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class TaskResource {

    private final TaskService taskService;

    @Inject
    public TaskResource(TaskService taskService) {
        this.taskService = taskService;
    }

    @Operation(operationId = "listTasks", summary = "List tasks, optionally by status or assignee")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = TaskResponse.class)))
    @GET
    public List<TaskResponse> list(
            @PathParam("householdId") UUID householdId,
            @QueryParam("status") TaskStatus status,
            @QueryParam("mine") @DefaultValue("false") boolean mine) {
        return taskService.list(householdId, status, mine).stream()
                .map(TaskResponse::from)
                .toList();
    }

    @Operation(
            operationId = "createOpenTask",
            summary = "Create an open task from a template (admin)")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = TaskResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    public Response createOpen(
            @PathParam("householdId") UUID householdId, @Valid CreateOpenTaskRequest request) {
        TaskResponse body =
                TaskResponse.from(
                        taskService.createOpen(
                                householdId,
                                request.templateId(),
                                request.assigneeId(),
                                request.dueAt()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @Operation(
            operationId = "quickLogTask",
            summary = "Log a chore just done: created already done for the caller")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = TaskResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/manual")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response quickLog(
            @PathParam("householdId") UUID householdId, @Valid QuickLogRequest request) {
        TaskResponse body =
                TaskResponse.from(taskService.quickLog(householdId, request.templateId()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @Operation(operationId = "completeTask", summary = "Complete a task (assignee or admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = TaskResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/{taskId}/complete")
    public TaskResponse complete(
            @PathParam("householdId") UUID householdId, @PathParam("taskId") UUID taskId) {
        return TaskResponse.from(taskService.complete(householdId, taskId));
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = TaskResponse.class)))
    @Operation(
            operationId = "dismissTask",
            summary = "Dismiss a task, irreversibly (assignee or admin)")
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/{taskId}/dismiss")
    public TaskResponse dismiss(
            @PathParam("householdId") UUID householdId, @PathParam("taskId") UUID taskId) {
        return TaskResponse.from(taskService.dismiss(householdId, taskId));
    }

    @Operation(operationId = "revertTask", summary = "Revert a done task with a reason (admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = TaskResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/{taskId}/revert")
    @Consumes(MediaType.APPLICATION_JSON)
    public TaskResponse revert(
            @PathParam("householdId") UUID householdId,
            @PathParam("taskId") UUID taskId,
            @Valid RevertRequest request) {
        return TaskResponse.from(taskService.revert(householdId, taskId, request.reason()));
    }

    @Operation(operationId = "reassignTask", summary = "Reassign a task round robin (admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = TaskResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/{taskId}/reassign")
    public TaskResponse reassign(
            @PathParam("householdId") UUID householdId, @PathParam("taskId") UUID taskId) {
        return TaskResponse.from(taskService.reassign(householdId, taskId));
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = DismissedCount.class)))
    @Operation(
            operationId = "dismissAwayMemberTasks",
            summary = "Dismiss the open tasks of a member marked away (admin)")
    @POST
    @Path("/dismiss-away/{userId}")
    public DismissedCount dismissAway(
            @PathParam("householdId") UUID householdId, @PathParam("userId") UUID userId) {
        int count = taskService.dismissOpenTasksForAwayMember(householdId, userId);
        return new DismissedCount(count);
    }

    /** Replaced by {@link #dismissAway}: marking a member away now dismisses their open tasks. */
    @Deprecated
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ReassignedCount.class)))
    @Operation(
            operationId = "reassignAwayMemberTasks",
            summary = "Deprecated: reassign the open tasks of an away member (admin)")
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/reassign-away/{userId}")
    public ReassignedCount reassignAway(
            @PathParam("householdId") UUID householdId, @PathParam("userId") UUID userId) {
        int count = taskService.reassignOpenTasksForAwayMember(householdId, userId);
        return new ReassignedCount(count);
    }
}
