package com.betterhome.tasks.ledger;

import com.betterhome.tasks.domain.TaskException;
import io.quarkus.oidc.client.OidcClientException;
import io.quarkus.oidc.client.Tokens;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.UUID;
import java.util.function.Consumer;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Writes the points ledger through scoring-service with this service's own client-credentials
 * token. A failed call throws, so the task transaction that triggered it rolls back instead of
 * leaving a done task without points.
 */
@ApplicationScoped
public class HttpPointsLedgerClient implements PointsLedgerClient {

    private final ScoringClient scoring;
    private final Tokens tokens;

    @Inject
    public HttpPointsLedgerClient(@RestClient ScoringClient scoring, Tokens tokens) {
        this.scoring = scoring;
        this.tokens = tokens;
    }

    @Override
    public void award(
            UUID householdId,
            UUID userId,
            UUID taskId,
            int completionNo,
            int points,
            boolean late) {
        String reason = late ? "task_completed_late" : "task_completed";
        call(
                bearer ->
                        scoring.award(
                                bearer,
                                householdId,
                                new ScoringClient.AwardRequest(
                                        userId, taskId, completionNo, points, reason)));
    }

    @Override
    public void reverse(
            UUID householdId,
            UUID taskId,
            UUID assigneeUserId,
            int points,
            UUID adminUserId,
            String reason,
            String resultingStatus) {
        call(
                bearer ->
                        scoring.reverse(
                                bearer,
                                householdId,
                                new ScoringClient.ReverseRequest(
                                        taskId,
                                        assigneeUserId,
                                        adminUserId,
                                        points,
                                        reason,
                                        resultingStatus)));
    }

    private void call(Consumer<String> request) {
        try {
            request.accept("Bearer " + tokens.getAccessToken());
        } catch (WebApplicationException e) {
            int status = e.getResponse().getStatus();
            if (status == 409) {
                throw new TaskException.Conflict("scoring-service refused the ledger change");
            }
            throw new TaskException.ServiceUnavailable("scoring-service answered " + status);
        } catch (ProcessingException | OidcClientException e) {
            throw new TaskException.ServiceUnavailable("scoring-service is unreachable");
        }
    }
}
