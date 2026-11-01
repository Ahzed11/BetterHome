package com.betterhome.notifications.service;

import com.betterhome.common.Clock;
import com.betterhome.common.PushSender;
import com.betterhome.common.PushSender.Outcome;
import com.betterhome.common.RelayBackoff;
import com.betterhome.notifications.domain.Notification;
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

/**
 * Sends the push rows and keeps their state. Each row is claimed in its own transaction with {@code
 * FOR UPDATE SKIP LOCKED}, so replicas never send one row twice at the same time. A row the push
 * server could not take is tried again with the backoff of the outbox relays, up to {@link
 * #MAX_ATTEMPTS} times; a row that can never be delivered, or whose retries ran out, is parked.
 */
@ApplicationScoped
public class PushDelivery {

    /** Failed attempts after which a push is given up (about an hour with the relay backoff). */
    static final int MAX_ATTEMPTS = 10;

    private static final String CLAIM_DUE =
            """
            SELECT id FROM notification
            WHERE channel = 'push' AND push_available_at IS NOT NULL
              AND pushed_at IS NULL AND push_failed_at IS NULL
              AND push_available_at <= :now
            ORDER BY push_available_at
            FOR UPDATE SKIP LOCKED
            LIMIT 1
            """;

    private static final String CLAIM_ONE =
            """
            SELECT id FROM notification
            WHERE id = :id AND channel = 'push' AND push_available_at IS NOT NULL
              AND pushed_at IS NULL AND push_failed_at IS NULL
              AND push_available_at <= :now
            FOR UPDATE SKIP LOCKED
            """;

    private final PushSender pushSender;
    private final Clock clock;
    private final EntityManager entityManager;
    private final ObjectMapper json;

    @Inject
    public PushDelivery(
            PushSender pushSender, Clock clock, EntityManager entityManager, ObjectMapper json) {
        this.pushSender = pushSender;
        this.clock = clock;
        this.entityManager = entityManager;
        this.json = json;
    }

    /** Tries the given push row now, if it is due and nobody else holds it. */
    public void attempt(UUID id) {
        QuarkusTransaction.requiringNew().run(() -> claim(CLAIM_ONE, id));
    }

    /** Sends up to {@code limit} due rows and returns how many it claimed. */
    public int retryDue(int limit) {
        int claimed = 0;
        while (claimed < limit
                && Boolean.TRUE.equals(
                        QuarkusTransaction.requiringNew().call(() -> claim(CLAIM_DUE, null)))) {
            claimed++;
        }
        return claimed;
    }

    private boolean claim(String query, UUID id) {
        Instant now = clock.now();
        var claim = entityManager.createNativeQuery(query).setParameter("now", Timestamp.from(now));
        if (id != null) {
            claim.setParameter("id", id);
        }
        List<?> ids = claim.getResultList();
        if (ids.isEmpty()) {
            return false;
        }
        Object rawId = ids.getFirst();
        UUID rowId = rawId instanceof UUID uuid ? uuid : UUID.fromString(rawId.toString());
        deliver(Notification.findById(rowId), now);
        return true;
    }

    private void deliver(Notification row, Instant now) {
        Outcome outcome =
                pushSender.send(
                        new PushSender.PushMessage(
                                row.userId.toString(),
                                row.type.name(),
                                row.title,
                                row.body,
                                payloadJson(row)));
        switch (outcome) {
            case SENT -> row.pushedAt = clock.now();
            case UNDELIVERABLE -> row.pushFailedAt = now;
            case RETRY -> {
                row.pushAttempts++;
                if (row.pushAttempts >= MAX_ATTEMPTS) {
                    row.pushFailedAt = now;
                } else {
                    row.pushAvailableAt = now.plus(RelayBackoff.delay(row.pushAttempts));
                }
            }
        }
    }

    private String payloadJson(Notification row) {
        try {
            return json.writeValueAsString(row.payload);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Payload of strings cannot be serialized", e);
        }
    }
}
