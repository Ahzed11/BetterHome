package com.betterhome.households.service;

import io.quarkus.oidc.client.filter.OidcClientFilter;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.QueryParam;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * Service-account boundary to tasks-service for background jobs, where no user token exists. The
 * filter sends this service's own client-credentials token.
 */
@RegisterRestClient(configKey = "tasks")
@OidcClientFilter
@Path("/v1/internal/households/{householdId}/tasks")
public interface TasksInternalClient {

    record DismissedCount(int dismissed) {}

    /** Dismisses the open tasks of a member whose away period has started. */
    @POST
    @Path("/dismiss-away/{userId}")
    DismissedCount dismissAway(
            @PathParam("householdId") UUID householdId,
            @PathParam("userId") UUID userId,
            @QueryParam("dismissedBy") UUID dismissedBy);
}
