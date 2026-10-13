package com.betterhome.tasks.ledger;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.core.MediaType;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/** REST boundary to the ledger write endpoints of scoring-service (service role only). */
@RegisterRestClient(configKey = "scoring")
@Path("/v1/households/{householdId}/points")
@Consumes(MediaType.APPLICATION_JSON)
public interface ScoringClient {

    record AwardRequest(UUID userId, UUID taskId, int points, String reason) {}

    record ReverseRequest(
            UUID taskId,
            UUID assigneeUserId,
            UUID adminUserId,
            int points,
            String reason,
            String resultingStatus) {}

    @POST
    @Path("/award")
    void award(
            @HeaderParam("Authorization") String authorization,
            @PathParam("householdId") UUID householdId,
            AwardRequest request);

    @POST
    @Path("/reverse")
    void reverse(
            @HeaderParam("Authorization") String authorization,
            @PathParam("householdId") UUID householdId,
            ReverseRequest request);
}
