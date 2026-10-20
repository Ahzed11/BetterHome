package com.betterhome.households.erasure;

import io.quarkus.oidc.client.filter.OidcClientFilter;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/** Service-account boundary to the anonymize endpoint of notifications-service. */
@RegisterRestClient(configKey = "notifications")
@OidcClientFilter
@Path("/v1/internal/users/{userId}/anonymize")
public interface NotificationsAnonymizeClient {

    @POST
    void anonymize(@PathParam("userId") UUID userId);
}
