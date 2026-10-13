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

@Path("/v1/households/{householdId}/templates")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TemplateResource {

    private final TemplateService templateService;

    @Inject
    public TemplateResource(TemplateService templateService) {
        this.templateService = templateService;
    }

    @GET
    public List<TemplateResponse> list(@PathParam("householdId") UUID householdId) {
        return templateService.list(householdId).stream().map(TemplateResponse::from).toList();
    }

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

    @POST
    @Path("/{templateId}/archive")
    public TemplateResponse archive(
            @PathParam("householdId") UUID householdId,
            @PathParam("templateId") UUID templateId) {
        return TemplateResponse.from(templateService.archive(householdId, templateId));
    }
}
