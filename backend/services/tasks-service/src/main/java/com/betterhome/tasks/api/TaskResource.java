package com.betterhome.tasks.api;

import com.betterhome.tasks.api.TaskDtos.CreateOpenTaskRequest;
import com.betterhome.tasks.api.TaskDtos.QuickLogRequest;
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
import java.util.Map;
import java.util.UUID;

@Path("/v1/households/{householdId}/tasks")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TaskResource {

    private final TaskService taskService;

    @Inject
    public TaskResource(TaskService taskService) {
        this.taskService = taskService;
    }

    @GET
    public List<TaskResponse> list(
            @PathParam("householdId") UUID householdId,
            @QueryParam("status") TaskStatus status,
            @QueryParam("mine") @DefaultValue("false") boolean mine) {
        return taskService.list(householdId, status, mine).stream()
                .map(TaskResponse::from)
                .toList();
    }

    @POST
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

    @POST
    @Path("/manual")
    public Response quickLog(
            @PathParam("householdId") UUID householdId, @Valid QuickLogRequest request) {
        TaskResponse body =
                TaskResponse.from(taskService.quickLog(householdId, request.templateId()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @POST
    @Path("/{taskId}/complete")
    public TaskResponse complete(
            @PathParam("householdId") UUID householdId, @PathParam("taskId") UUID taskId) {
        return TaskResponse.from(taskService.complete(householdId, taskId));
    }

    @POST
    @Path("/{taskId}/dismiss")
    public TaskResponse dismiss(
            @PathParam("householdId") UUID householdId, @PathParam("taskId") UUID taskId) {
        return TaskResponse.from(taskService.dismiss(householdId, taskId));
    }

    @POST
    @Path("/{taskId}/revert")
    public TaskResponse revert(
            @PathParam("householdId") UUID householdId,
            @PathParam("taskId") UUID taskId,
            @Valid RevertRequest request) {
        return TaskResponse.from(taskService.revert(householdId, taskId, request.reason()));
    }

    @POST
    @Path("/{taskId}/reassign")
    public TaskResponse reassign(
            @PathParam("householdId") UUID householdId, @PathParam("taskId") UUID taskId) {
        return TaskResponse.from(taskService.reassign(householdId, taskId));
    }

    @POST
    @Path("/dismiss-away/{userId}")
    public Map<String, Integer> dismissAway(
            @PathParam("householdId") UUID householdId, @PathParam("userId") UUID userId) {
        int count = taskService.dismissOpenTasksForAwayMember(householdId, userId);
        return Map.of("dismissed", count);
    }

    /** Replaced by {@link #dismissAway}: marking a member away now dismisses their open tasks. */
    @Deprecated
    @POST
    @Path("/reassign-away/{userId}")
    public Map<String, Integer> reassignAway(
            @PathParam("householdId") UUID householdId, @PathParam("userId") UUID userId) {
        int count = taskService.reassignOpenTasksForAwayMember(householdId, userId);
        return Map.of("reassigned", count);
    }
}
