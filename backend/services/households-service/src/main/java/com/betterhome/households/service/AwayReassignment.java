package com.betterhome.households.service;

import io.quarkus.security.credential.TokenCredential;
import io.quarkus.security.identity.SecurityIdentity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.enterprise.event.TransactionPhase;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;

/**
 * After an away change commits, asks tasks-service to reassign the member's open tasks with the
 * admin's own token. A failure is logged and never undoes the away change.
 */
@ApplicationScoped
public class AwayReassignment {

    private static final Logger LOG = Logger.getLogger(AwayReassignment.class);

    private final TasksClient tasksClient;
    private final SecurityIdentity identity;

    @Inject
    public AwayReassignment(@RestClient TasksClient tasksClient, SecurityIdentity identity) {
        this.tasksClient = tasksClient;
        this.identity = identity;
    }

    void onMemberAway(@Observes(during = TransactionPhase.AFTER_SUCCESS) MemberAway event) {
        TokenCredential token = identity.getCredential(TokenCredential.class);
        if (token == null) {
            LOG.warnf(
                    "No access token to reassign tasks of away member %s in household %s",
                    event.userId(), event.householdId());
            return;
        }
        try {
            tasksClient.reassignAway(
                    "Bearer " + token.getToken(), event.householdId(), event.userId());
        } catch (WebApplicationException | ProcessingException e) {
            LOG.warnf(
                    e,
                    "Could not reassign tasks of away member %s in household %s",
                    event.userId(),
                    event.householdId());
        }
    }
}
