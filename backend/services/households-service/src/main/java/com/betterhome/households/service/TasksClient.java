package com.betterhome.households.service;

import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/** REST boundary to tasks-service. Households never touches the tasks database. */
@RegisterRestClient(configKey = "tasks")
@Path("/v1/households/{householdId}/tasks")
public interface TasksClient {

    /** Moves the open tasks of an away member to eligible members (round robin). */
    @POST
    @Path("/reassign-away/{userId}")
    void reassignAway(
            @HeaderParam("Authorization") String authorization,
            @PathParam("householdId") UUID householdId,
            @PathParam("userId") UUID userId);
}
