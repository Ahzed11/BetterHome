package com.betterhome.scoring.api;

import com.betterhome.scoring.api.ScoringDtos.CelebrationSeen;
import com.betterhome.scoring.api.ScoringDtos.CloseMonthRequest;
import com.betterhome.scoring.api.ScoringDtos.ScoreboardResponse;
import com.betterhome.scoring.api.ScoringDtos.WinnerResponse;
import com.betterhome.scoring.domain.ScorePeriod;
import com.betterhome.scoring.service.ScoreboardService;
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

@Path("/v1/households/{householdId}/scoreboard")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "scoreboard")
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
public class ScoreboardResource {

    private final ScoreboardService scoreboardService;

    @Inject
    public ScoreboardResource(ScoreboardService scoreboardService) {
        this.scoreboardService = scoreboardService;
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ScoreboardResponse.class)))
    @Operation(
            operationId = "getScoreboard",
            summary = "Scoreboard for a period with podium and effort shares")
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @GET
    public ScoreboardResponse get(
            @PathParam("householdId") UUID householdId,
            @QueryParam("period") @DefaultValue("month") ScorePeriod period,
            @QueryParam("yearMonth") String yearMonth) {
        return ScoreboardResponse.from(
                scoreboardService.scoreboard(householdId, period, yearMonth));
    }

    @Operation(operationId = "listWinners", summary = "Hall of past monthly winners")
    @APIResponse(
            responseCode = "200",
            description = "OK",
            content =
                    @Content(
                            schema =
                                    @Schema(
                                            type = SchemaType.ARRAY,
                                            implementation = WinnerResponse.class)))
    @GET
    @Path("/winners")
    public List<WinnerResponse> winners(@PathParam("householdId") UUID householdId) {
        return scoreboardService.winners(householdId).stream().map(WinnerResponse::from).toList();
    }

    @Operation(operationId = "closeMonth", summary = "Close a month and record its winner (admin)")
    @APIResponse(
            responseCode = "200",
            description = "Closed",
            content = @Content(schema = @Schema(implementation = WinnerResponse.class)))
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/close-month")
    public Response closeMonth(
            @PathParam("householdId") UUID householdId, @Valid CloseMonthRequest request) {
        var recap = scoreboardService.closeMonth(householdId, request.yearMonth());
        return Response.ok(
                        new WinnerResponse(
                                recap.yearMonth,
                                recap.winnerUserId,
                                recap.winnerPoints,
                                recap.totalPoints))
                .build();
    }

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = CelebrationSeen.class)))
    @Operation(
            operationId = "markRecapCelebrated",
            summary = "Record that the caller has seen the month confetti")
    @APIResponse(
            responseCode = "400",
            description = "Invalid input",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @POST
    @Path("/recaps/{yearMonth}/celebrate")
    public CelebrationSeen celebrate(
            @PathParam("householdId") UUID householdId, @PathParam("yearMonth") String yearMonth) {
        scoreboardService.markCelebrated(householdId, yearMonth);
        return new CelebrationSeen(true);
    }
}
