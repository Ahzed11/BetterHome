package com.betterhome.households.service;

import com.betterhome.households.domain.HouseholdException;
import io.quarkus.security.credential.TokenCredential;
import io.quarkus.security.identity.SecurityIdentity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Asks tasks-service to dismiss the open tasks of a member who was marked away, with the admin's
 * own token. Called inside the away transaction: a failure here fails the request and the away
 * change is rolled back.
 */
@ApplicationScoped
public class AwayTaskDismissal {

    private final TasksClient tasksClient;
    private final SecurityIdentity identity;

    @Inject
    public AwayTaskDismissal(@RestClient TasksClient tasksClient, SecurityIdentity identity) {
        this.tasksClient = tasksClient;
        this.identity = identity;
    }

    public void dismissOpenTasks(UUID householdId, UUID userId) {
        TokenCredential token = identity.getCredential(TokenCredential.class);
        if (token == null) {
            throw new HouseholdException.Unauthorized("Access token required");
        }
        try {
            tasksClient.dismissAway("Bearer " + token.getToken(), householdId, userId);
        } catch (WebApplicationException e) {
            throw new HouseholdException.ServiceUnavailable(
                    "tasks-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException e) {
            throw new HouseholdException.ServiceUnavailable("tasks-service is unreachable");
        }
    }
}
