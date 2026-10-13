package com.betterhome.tasks.api;

import com.betterhome.tasks.api.TaskDtos.CreateTemplateRequest;
import com.betterhome.tasks.api.TaskDtos.TemplateResponse;
import com.betterhome.tasks.api.TaskDtos.UpdateTemplateRequest;
import com.betterhome.tasks.service.TemplateService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
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

@Path("/v1/households/{householdId}/templates")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "templates")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class TemplateResource {

    private final TemplateService templateService;

    @Inject
    public TemplateResource(TemplateService templateService) {
        this.templateService = templateService;
    }

    @Operation(operationId = "listTemplates", summary = "List active templates")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = TemplateResponse.class)))
    @GET
    public List<TemplateResponse> list(@PathParam("householdId") UUID householdId) {
        return templateService.list(householdId).stream().map(TemplateResponse::from).toList();
    }

    @Operation(operationId = "createTemplate", summary = "Create a template (admin)")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = TemplateResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    public Response create(
            @PathParam("householdId") UUID householdId, @Valid CreateTemplateRequest request) {
        TemplateResponse body =
                TemplateResponse.from(
                        templateService.create(
                                householdId,
                                request.title(),
                                request.emoji(),
                                request.description(),
                                request.points(),
                                request.latePoints(),
                                request.defaultDueOffsetMinutes()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = TemplateResponse.class)))
    @Operation(
            operationId = "updateTemplate",
            summary = "Update a template (admin); existing tasks are unchanged")
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @PATCH
    @Path("/{templateId}")
    public TemplateResponse update(
            @PathParam("householdId") UUID householdId,
            @PathParam("templateId") UUID templateId,
            UpdateTemplateRequest request) {
        return TemplateResponse.from(
                templateService.update(
                        householdId,
                        templateId,
                        request.title(),
                        request.emoji(),
                        request.description(),
                        request.points(),
                        request.latePoints(),
                        request.defaultDueOffsetMinutes()));
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = TemplateResponse.class)))
    @Operation(
            operationId = "archiveTemplate",
            summary = "Archive a template and stop its recurrence (admin)")
    @POST
    @Path("/{templateId}/archive")
    public TemplateResponse archive(
            @PathParam("householdId") UUID householdId, @PathParam("templateId") UUID templateId) {
        return TemplateResponse.from(templateService.archive(householdId, templateId));
    }
}
