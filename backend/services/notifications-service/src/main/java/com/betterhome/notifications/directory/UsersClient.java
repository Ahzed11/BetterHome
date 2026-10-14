package com.betterhome.notifications.directory;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * REST boundary to the internal user endpoints of households-service (service accounts only).
 * Notifications never reads the households database.
 */
@RegisterRestClient(configKey = "households")
@Path("/v1/internal/users")
public interface UsersClient {

    record User(UUID userId, UUID authSubject, String language) {}

    @GET
    @Path("/{userId}")
    User byId(@HeaderParam("Authorization") String authorization, @PathParam("userId") UUID userId);

    @GET
    @Path("/by-subject/{authSubject}")
    User bySubject(
            @HeaderParam("Authorization") String authorization,
            @PathParam("authSubject") UUID authSubject);
}
