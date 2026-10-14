package com.betterhome.scoring.api;

import com.betterhome.scoring.api.ScoringDtos.AdjustRequest;
import com.betterhome.scoring.api.ScoringDtos.AwardRequest;
import com.betterhome.scoring.api.ScoringDtos.ReverseRequest;
import com.betterhome.scoring.api.ScoringDtos.ReversionResponse;
import com.betterhome.scoring.api.ScoringDtos.TransactionResponse;
import com.betterhome.scoring.service.LedgerService;
import io.quarkus.security.Authenticated;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
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

@Path("/v1/households/{householdId}/points")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "points")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "503",
        description = "A service this one depends on is unavailable",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
@APIResponse(
        responseCode = "404",
        description = "Not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
public class LedgerResource {

    private final LedgerService ledgerService;

    @Inject
    public LedgerResource(LedgerService ledgerService) {
        this.ledgerService = ledgerService;
    }

    @Operation(
            operationId = "awardPoints",
            summary = "Append an award to the ledger, once per task completion (service role)")
    @RolesAllowed("service")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = TransactionResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "A different award already exists for this task completion",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/award")
    public Response award(@PathParam("householdId") UUID householdId, @Valid AwardRequest request) {
        TransactionResponse body =
                TransactionResponse.from(
                        ledgerService.award(
                                householdId,
                                request.userId(),
                                request.taskId(),
                                request.completionNo(),
                                request.points(),
                                request.reason()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @Operation(
            operationId = "reversePoints",
            summary = "Append a reversal linked to its reversion record (service role)")
    @RolesAllowed("service")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = ReversionResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/reverse")
    public Response reverse(
            @PathParam("householdId") UUID householdId, @Valid ReverseRequest request) {
        ReversionResponse body =
                ReversionResponse.from(
                        ledgerService.reverse(
                                householdId,
                                request.taskId(),
                                request.assigneeUserId(),
                                request.adminUserId(),
                                request.points(),
                                request.reason(),
                                request.resultingStatus()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

    @Operation(operationId = "adjustPoints", summary = "Manually adjust a member score (admin)")
    @APIResponse(
            responseCode = "201",
            description = "Created",
            content = @Content(schema = @Schema(implementation = TransactionResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(
            responseCode = "409",
            description = "Conflicts with the current state",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/adjust")
    public Response adjust(
            @PathParam("householdId") UUID householdId, @Valid AdjustRequest request) {
        TransactionResponse body =
                TransactionResponse.from(
                        ledgerService.adjust(householdId, request.userId(), request.delta()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }
}
