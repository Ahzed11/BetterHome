package com.betterhome.lists.membership;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * REST boundary to the internal endpoints of households-service (service accounts only). Lists
 * never reads the households database.
 */
@RegisterRestClient(configKey = "households")
@Path("/v1/internal/households/{householdId}")
public interface HouseholdsClient {

    record Member(UUID userId, UUID authSubject, String role, boolean away, Instant joinedAt) {}

    @GET
    @Path("/members")
    List<Member> members(
            @HeaderParam("Authorization") String authorization,
            @PathParam("householdId") UUID householdId);
}
