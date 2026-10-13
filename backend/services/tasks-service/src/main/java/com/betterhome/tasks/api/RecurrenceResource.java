package com.betterhome.tasks.api;

import com.betterhome.tasks.api.TaskDtos.RecurrenceResponse;
import com.betterhome.tasks.api.TaskDtos.UpsertRecurrenceRequest;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.service.RecurrenceService;
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
import jakarta.ws.rs.core.Response;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/v1/households/{householdId}/templates/{templateId}/recurrence")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "recurrence")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class RecurrenceResource {

    private final RecurrenceService recurrenceService;

    @Inject
    public RecurrenceResource(RecurrenceService recurrenceService) {
        this.recurrenceService = recurrenceService;
    }

    @Operation(operationId = "getRecurrence", summary = "Get a template recurrence")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = RecurrenceResponse.class)))
    @GET
    public RecurrenceResponse get(
            @PathParam("householdId") UUID householdId, @PathParam("templateId") UUID templateId) {
        return RecurrenceResponse.from(
                recurrenceService
                        .find(householdId, templateId)
                        .orElseThrow(() -> new TaskException.NotFound("Recurrence not found")));
    }

    @Operation(
            operationId = "upsertRecurrence",
            summary = "Create or replace a template recurrence (admin)")
    @APIResponse(
            responseCode = "200",
            description = "Saved",
            content = @Content(schema = @Schema(implementation = RecurrenceResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @PUT
    public Response upsert(
            @PathParam("householdId") UUID householdId,
            @PathParam("templateId") UUID templateId,
            @Valid UpsertRecurrenceRequest request) {
        RecurrenceResponse body =
                RecurrenceResponse.from(
                        recurrenceService.upsert(
                                householdId,
                                templateId,
                                request.rrule(),
                                request.assignmentMode(),
                                request.fixedAssigneeId(),
                                request.startsAt(),
                                request.endsAt()));
        return Response.ok(body).build();
    }
}
