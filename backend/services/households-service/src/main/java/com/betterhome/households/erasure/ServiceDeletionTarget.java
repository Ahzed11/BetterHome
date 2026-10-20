package com.betterhome.households.erasure;

import io.quarkus.oidc.client.OidcClientException;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.UUID;

/**
 * A BetterHome service with an internal anonymize endpoint (service role, ADR 0014). Any failed
 * call, an answer other than success included, makes the deletion retry later: the endpoints are
 * idempotent, so repeating a call that did succeed is harmless.
 */
public abstract class ServiceDeletionTarget implements DeletionTarget {

    /** Calls the service's {@code POST /v1/internal/users/{userId}/anonymize}. */
    protected abstract void anonymize(UUID userId);

    @Override
    public void erase(UUID userId, UUID authSubject) {
        try {
            anonymize(userId);
        } catch (WebApplicationException e) {
            throw new DeletionTargetException(
                    name() + "-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException | OidcClientException e) {
            throw new DeletionTargetException(name() + "-service is unreachable");
        }
    }
}
