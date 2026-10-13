package com.betterhome.scoring.api;

import com.betterhome.scoring.api.ScoringDtos.AdjustRequest;
import com.betterhome.scoring.api.ScoringDtos.AwardRequest;
import com.betterhome.scoring.api.ScoringDtos.ReverseRequest;
import com.betterhome.scoring.api.ScoringDtos.ReversionResponse;
import com.betterhome.scoring.api.ScoringDtos.TransactionResponse;
import com.betterhome.scoring.service.LedgerService;
import io.quarkus.security.Authenticated;
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

@Path("/v1/households/{householdId}/points")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class LedgerResource {

    private final LedgerService ledgerService;

    @Inject
    public LedgerResource(LedgerService ledgerService) {
        this.ledgerService = ledgerService;
    }

    @POST
    @Path("/award")
    public Response award(@PathParam("householdId") UUID householdId, @Valid AwardRequest request) {
        TransactionResponse body =
                TransactionResponse.from(
                        ledgerService.award(
                                householdId,
                                request.userId(),
                                request.taskId(),
                                request.points(),
                                request.reason()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

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
                                request.points(),
                                request.reason(),
                                request.resultingStatus()));
        return Response.status(Response.Status.CREATED).entity(body).build();
    }

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
