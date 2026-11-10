package com.betterhome.notifications.service;

import com.betterhome.common.Clock;
import com.betterhome.common.PushSender;
import com.betterhome.common.RelayBackoff;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.PushState;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.jboss.logging.Logger;

/**
 * Delivers the push rows (ADR 0017, T-0105). Each attempt claims its row in its own transaction
 * with {@code FOR UPDATE SKIP LOCKED}, so replicas never push one row at the same time and a row
 * that is no longer pending is never pushed again. A push Gotify could not take (timeout,
 * connection error, 5xx) stays pending and is tried again after {@link RelayBackoff}, up to {@link
 * #MAX_ATTEMPTS} attempts; a refusal is final. A row whose outcome was not committed when the
 * service stopped is pushed again, so delivery is at least once for that case only.
 */
@ApplicationScoped
public class PushDelivery {

    /** With the backoff capped at 15 minutes, the last attempt comes about 35 minutes in. */
    static final int MAX_ATTEMPTS = 10;

    private static final Logger LOG = Logger.getLogger(PushDelivery.class);

    private final Clock clock;
    private final PushSender pushSender;
    private final EntityManager entityManager;
    private final ObjectMapper json;

    @Inject
    public PushDelivery(
            Clock clock, PushSender pushSender, EntityManager entityManager, ObjectMapper json) {
        this.clock = clock;
        this.pushSender = pushSender;
        this.entityManager = entityManager;
        this.json = json;
    }

    /** Tries the row once if it is pending and due; true when this call tried it. */
    public boolean attempt(UUID id) {
        return Boolean.TRUE.equals(
                QuarkusTransaction.requiringNew().call(() -> claimAndSend(id, clock.now())));
    }

    /** Tries up to {@code limit} due pending rows and returns how many it tried. */
    public int retryDue(int limit) {
        int tried = 0;
        while (tried < limit
                && Boolean.TRUE.equals(
                        QuarkusTransaction.requiringNew()
                                .call(() -> claimAndSend(null, clock.now())))) {
            tried++;
        }
        return tried;
    }

    /** One row, or the oldest due one when {@code id} is null. */
    private boolean claimAndSend(UUID id, Instant now) {
        List<?> ids =
                entityManager
                        .createNativeQuery(
                                """
                                SELECT id FROM notification
                                WHERE push_state = 'pending' AND push_available_at <= :now
                                  AND (CAST(:id AS uuid) IS NULL OR id = CAST(:id AS uuid))
                                ORDER BY push_available_at
                                FOR UPDATE SKIP LOCKED
                                LIMIT 1
                                """)
                        .setParameter("now", Timestamp.from(now))
                        .setParameter("id", id)
                        .getResultList();
        if (ids.isEmpty()) {
            return false;
        }
        Notification row = Notification.findById(UUID.fromString(ids.getFirst().toString()));
        record(row, pushSender.send(message(row)), now);
        return true;
    }

    private void record(Notification row, PushSender.Outcome outcome, Instant now) {
        row.pushAttempts++;
        switch (outcome) {
            case DELIVERED -> finish(row, PushState.sent);
            case SKIPPED -> finish(row, PushState.skipped);
            case REFUSED -> finish(row, PushState.refused);
            case UNAVAILABLE -> {
                if (row.pushAttempts >= MAX_ATTEMPTS) {
                    finish(row, PushState.gave_up);
                    LOG.warnf(
                            "Push %s (%s) given up after %d attempts",
                            row.id, row.type, row.pushAttempts);
                } else {
                    row.pushAvailableAt = now.plus(RelayBackoff.delay(row.pushAttempts));
                    LOG.warnf(
                            "Push %s (%s) not delivered, attempt %d",
                            row.id, row.type, row.pushAttempts);
                }
            }
        }
    }

    private static void finish(Notification row, PushState state) {
        row.pushState = state;
        row.pushAvailableAt = null;
    }

    private PushSender.PushMessage message(Notification row) {
        try {
            return new PushSender.PushMessage(
                    row.userId.toString(),
                    row.type.name(),
                    row.title,
                    row.body,
                    json.writeValueAsString(row.payload));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Payload of strings cannot be serialized", e);
        }
    }
}
