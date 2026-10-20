package com.betterhome.households.erasure;

import io.quarkus.oidc.client.filter.OidcClientFilter;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * Keycloak Admin REST API, realm scope ({@code .../admin/realms/{realm}}). The service account of
 * this service needs the {@code manage-users} role of the realm-management client.
 */
@RegisterRestClient(configKey = "keycloak-admin")
@OidcClientFilter
@Path("/users")
public interface KeycloakAdminClient {

    @DELETE
    @Path("/{id}")
    void deleteUser(@PathParam("id") UUID id);
}
