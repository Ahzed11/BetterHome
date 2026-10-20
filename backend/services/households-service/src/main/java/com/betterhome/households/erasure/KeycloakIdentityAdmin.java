package com.betterhome.households.erasure;

import io.quarkus.oidc.client.OidcClientException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/** Deletes users through the Keycloak Admin REST API. An account already gone counts as done. */
@ApplicationScoped
public class KeycloakIdentityAdmin implements IdentityAdmin {

    private final KeycloakAdminClient client;

    @Inject
    public KeycloakIdentityAdmin(@RestClient KeycloakAdminClient client) {
        this.client = client;
    }

    @Override
    public void deleteUser(UUID authSubject) {
        try {
            client.deleteUser(authSubject);
        } catch (WebApplicationException e) {
            // 404 means the account is already gone, which is what was asked for
            if (e.getResponse().getStatus() != 404) {
                throw new DeletionTargetException(
                        "Keycloak answered " + e.getResponse().getStatus());
            }
        } catch (ProcessingException | OidcClientException e) {
            throw new DeletionTargetException("Keycloak is unreachable");
        }
    }
}
