package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;

/**
 * Dismisses the open tasks of members whose future-dated away period has started. Each period is
 * claimed with {@code FOR UPDATE SKIP LOCKED} and handled in its own transaction, so replicas never
 * handle the same period and a failed call leaves it due for the next run.
 */
@ApplicationScoped
public class AwayStartDismissal {

    private static final Logger LOG = Logger.getLogger(AwayStartDismissal.class);

    private final EntityManager entityManager;
    private final TasksInternalClient tasksClient;
    private final Clock clock;

    @Inject
    public AwayStartDismissal(
            EntityManager entityManager, @RestClient TasksInternalClient tasksClient, Clock clock) {
        this.entityManager = entityManager;
        this.tasksClient = tasksClient;
        this.clock = clock;
    }

    /**
     * Handles every period that is due now.
     *
     * @return how many periods were handled; stops early, leaving the rest due, when tasks-service
     *     cannot be reached
     */
    public int dismissDue() {
        int handled = 0;
        try {
            while (QuarkusTransaction.requiringNew().call(this::dismissNextDue)) {
                handled++;
            }
        } catch (HouseholdException.ServiceUnavailable e) {
            LOG.warnf("Away start dismissal postponed: %s", e.getMessage());
        }
        return handled;
    }

    private boolean dismissNextDue() {
        Instant now = clock.now();
        List<?> claimed =
                entityManager
                        .createNativeQuery(
                                """
                                SELECT id FROM membership
                                WHERE left_at IS NULL
                                  AND away_from <= :now
                                  AND (away_until IS NULL OR away_until >= :now)
                                  AND away_tasks_dismissed_at IS NULL
                                ORDER BY away_from
                                LIMIT 1
                                FOR UPDATE SKIP LOCKED
                                """)
                        .setParameter("now", Timestamp.from(now))
                        .getResultList();
        if (claimed.isEmpty()) {
            return false;
        }
        Membership membership = Membership.findById(UUID.fromString(claimed.get(0).toString()));
        dismiss(membership);
        membership.awayTasksDismissedAt = now;
        return true;
    }

    private void dismiss(Membership membership) {
        try {
            tasksClient.dismissAway(
                    membership.householdId, membership.userId, membership.awaySetBy);
        } catch (WebApplicationException e) {
            throw new HouseholdException.ServiceUnavailable(
                    "tasks-service answered " + e.getResponse().getStatus());
        } catch (ProcessingException e) {
            throw new HouseholdException.ServiceUnavailable("tasks-service is unreachable");
        }
    }
}
