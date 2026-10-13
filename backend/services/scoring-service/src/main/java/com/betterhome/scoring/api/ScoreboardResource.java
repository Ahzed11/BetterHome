package com.betterhome.scoring.api;

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
import java.util.Map;
import java.util.UUID;

@Path("/v1/households/{householdId}/scoreboard")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ScoreboardResource {

    private final ScoreboardService scoreboardService;

    @Inject
    public ScoreboardResource(ScoreboardService scoreboardService) {
        this.scoreboardService = scoreboardService;
    }

    @GET
    public ScoreboardResponse get(
            @PathParam("householdId") UUID householdId,
            @QueryParam("period") @DefaultValue("month") ScorePeriod period,
            @QueryParam("yearMonth") String yearMonth) {
        return ScoreboardResponse.from(
                scoreboardService.scoreboard(householdId, period, yearMonth));
    }

    @GET
    @Path("/winners")
    public List<WinnerResponse> winners(@PathParam("householdId") UUID householdId) {
        return scoreboardService.winners(householdId).stream().map(WinnerResponse::from).toList();
    }

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

    @POST
    @Path("/recaps/{yearMonth}/celebrate")
    public Map<String, Boolean> celebrate(
            @PathParam("householdId") UUID householdId, @PathParam("yearMonth") String yearMonth) {
        scoreboardService.markCelebrated(householdId, yearMonth);
        return Map.of("seen", true);
    }
}
