package com.betterhome.lists.api;

import com.betterhome.lists.api.ListDtos.ListResponse;
import com.betterhome.lists.api.ListDtos.TitleRequest;
import com.betterhome.lists.service.ChecklistService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PATCH;
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

@Path("/v1/households/{householdId}/lists")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "lists")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "503",
        description = "Membership cannot be checked right now",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class ListResource {

    private final ChecklistService checklistService;

    @Inject
    public ListResource(ChecklistService checklistService) {
        this.checklistService = checklistService;
    }

    @Operation(
            operationId = "listLists",
            summary = "List the household's lists; archived ones only when asked")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = ListResponse.class)))
    @GET
    public List<ListResponse> list(
            @PathParam("householdId") UUID householdId,
            @QueryParam("includeArchived") @DefaultValue("false") boolean includeArchived) {
        return checklistService.list(householdId, includeArchived).stream()
                .map(ListResponse::from)
                .toList();
    }

    @Operation(operationId = "createList", summary = "Create a list (admin)")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = ListResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @Consumes(MediaType.APPLICATION_JSON)
    @POST
    public Response create(
            @PathParam("householdId") UUID householdId, @Valid TitleRequest request) {
        ListResponse body =
                ListResponse.from(checklistService.create(householdId, request.title()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @Operation(operationId = "renameList", summary = "Rename an active list (admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ListResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "404",
            description = "Not found",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "The list is archived",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @Consumes(MediaType.APPLICATION_JSON)
    @PATCH
    @Path("/{listId}")
    public ListResponse rename(
            @PathParam("householdId") UUID householdId,
            @PathParam("listId") UUID listId,
            @Valid TitleRequest request) {
        return ListResponse.from(checklistService.rename(householdId, listId, request.title()));
    }

    @Operation(
            operationId = "archiveList",
            summary = "Archive a list; its items become read-only (admin)")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ListResponse.class)))
    @APIResponse(
            responseCode = "404",
            description = "Not found",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "The list is already archived",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/{listId}/archive")
    public ListResponse archive(
            @PathParam("householdId") UUID householdId, @PathParam("listId") UUID listId) {
        return ListResponse.from(checklistService.archive(householdId, listId));
    }
}
