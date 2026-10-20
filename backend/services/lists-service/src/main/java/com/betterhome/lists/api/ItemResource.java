package com.betterhome.lists.api;

import com.betterhome.lists.api.ListDtos.ItemResponse;
import com.betterhome.lists.api.ListDtos.TitleRequest;
import com.betterhome.lists.service.ItemService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
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

@Path("/v1/households/{householdId}/lists/{listId}")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "items")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not an active member of the household",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "503",
        description = "Membership cannot be checked right now",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class ItemResource {

    private static final String ARCHIVED = "The list is archived, its items cannot change";

    private final ItemService itemService;

    @Inject
    public ItemResource(ItemService itemService) {
        this.itemService = itemService;
    }

    @Operation(
            operationId = "listItems",
            summary = "Items of a list in position order, deleted ones left out")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = ItemResponse.class)))
    @GET
    @Path("/items")
    public List<ItemResponse> list(
            @PathParam("householdId") UUID householdId, @PathParam("listId") UUID listId) {
        return itemService.list(householdId, listId).stream().map(ItemResponse::from).toList();
    }

    @Operation(operationId = "addItem", summary = "Add an item at the end of the list")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = ItemResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = ARCHIVED,
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @Consumes(MediaType.APPLICATION_JSON)
    @POST
    @Path("/items")
    public Response add(
            @PathParam("householdId") UUID householdId,
            @PathParam("listId") UUID listId,
            @Valid TitleRequest request) {
        ItemResponse body =
                ItemResponse.from(itemService.add(householdId, listId, request.title()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @Operation(operationId = "renameItem", summary = "Edit an item's title")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ItemResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = ARCHIVED,
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @Consumes(MediaType.APPLICATION_JSON)
    @PATCH
    @Path("/items/{itemId}")
    public ItemResponse rename(
            @PathParam("householdId") UUID householdId,
            @PathParam("listId") UUID listId,
            @PathParam("itemId") UUID itemId,
            @Valid TitleRequest request) {
        return ItemResponse.from(itemService.rename(householdId, listId, itemId, request.title()));
    }

    @Operation(
            operationId = "checkItem",
            summary = "Check an item, recording who and when; awards no points")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ItemResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = ARCHIVED,
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/items/{itemId}/check")
    public ItemResponse check(
            @PathParam("householdId") UUID householdId,
            @PathParam("listId") UUID listId,
            @PathParam("itemId") UUID itemId) {
        return ItemResponse.from(itemService.check(householdId, listId, itemId));
    }

    @Operation(operationId = "uncheckItem", summary = "Uncheck an item")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ItemResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = ARCHIVED,
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/items/{itemId}/uncheck")
    public ItemResponse uncheck(
            @PathParam("householdId") UUID householdId,
            @PathParam("listId") UUID listId,
            @PathParam("itemId") UUID itemId) {
        return ItemResponse.from(itemService.uncheck(householdId, listId, itemId));
    }

    @Operation(
            operationId = "deleteItem",
            summary = "Soft-delete an item, keeping who deleted it and when")
    @APIResponse(responseCode = "204", description = "Deleted")
    @APIResponse(
            responseCode = "409",
            description = ARCHIVED,
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @DELETE
    @Path("/items/{itemId}")
    public Response delete(
            @PathParam("householdId") UUID householdId,
            @PathParam("listId") UUID listId,
            @PathParam("itemId") UUID itemId) {
        itemService.delete(householdId, listId, itemId);
        return Response.noContent().build();
    }

    @Operation(
            operationId = "resetList",
            summary = "Uncheck every item of the list (bulk reset, admin) and return the items")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = ItemResponse.class)))
    @APIResponse(
            responseCode = "403",
            description = "Not an active admin of the household",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = ARCHIVED,
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/reset")
    public List<ItemResponse> reset(
            @PathParam("householdId") UUID householdId, @PathParam("listId") UUID listId) {
        return itemService.reset(householdId, listId).stream().map(ItemResponse::from).toList();
    }
}
