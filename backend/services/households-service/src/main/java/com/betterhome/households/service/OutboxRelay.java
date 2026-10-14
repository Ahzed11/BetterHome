package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.common.NotificationDeliveryException;
import com.betterhome.common.NotificationEvent;
import com.betterhome.common.NotificationsGateway;
import com.betterhome.common.RelayBackoff;
import com.betterhome.households.domain.NotificationOutbox;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.jboss.logging.Logger;

/**
 * Delivers outbox rows to notifications-service at least once. Each row is claimed in its own
 * transaction with {@code FOR UPDATE SKIP LOCKED}, so several replicas never send the same row at
 * the same time; a row delivered but not yet committed when the service stops is sent again with
 * the same idempotency key, which notifications-service stores once (ADR 0017).
 */
@ApplicationScoped
public class OutboxRelay {

    private static final Logger LOG = Logger.getLogger(OutboxRelay.class);
    private static final TypeReference<Map<String, String>> PAYLOAD = new TypeReference<>() {};

    private final Clock clock;
    private final NotificationsGateway gateway;
    private final ObjectMapper objectMapper;
    private final EntityManager entityManager;

    @Inject
    public OutboxRelay(
            Clock clock,
            NotificationsGateway gateway,
            ObjectMapper objectMapper,
            EntityManager entityManager) {
        this.clock = clock;
        this.gateway = gateway;
        this.objectMapper = objectMapper;
        this.entityManager = entityManager;
    }

    /** Sends up to {@code limit} due rows and returns how many it claimed. */
    public int relayDue(int limit) {
        int claimed = 0;
        while (claimed < limit
                && Boolean.TRUE.equals(QuarkusTransaction.requiringNew().call(this::relayOne))) {
            claimed++;
        }
        return claimed;
    }

    private boolean relayOne() {
        Instant now = clock.now();
        List<?> ids =
                entityManager
                        .createNativeQuery(
                                """
                                SELECT id FROM notification_outbox
                                WHERE processed_at IS NULL AND failed_at IS NULL
                                  AND available_at <= :now
                                ORDER BY created_at
                                FOR UPDATE SKIP LOCKED
                                LIMIT 1
                                """)
                        .setParameter("now", Timestamp.from(now))
                        .getResultList();
        if (ids.isEmpty()) {
            return false;
        }
        Object rawId = ids.getFirst();
        UUID id = rawId instanceof UUID uuid ? uuid : UUID.fromString(rawId.toString());
        NotificationOutbox row = NotificationOutbox.findById(id);
        deliver(row, now);
        return true;
    }

    private void deliver(NotificationOutbox row, Instant now) {
        try {
            gateway.deliver(event(row));
            row.processedAt = clock.now();
        } catch (NotificationDeliveryException.Unavailable e) {
            row.attempts++;
            row.availableAt = now.plus(RelayBackoff.delay(row.attempts));
            LOG.warnf(
                    "Outbox row %s (%s) not delivered, attempt %d: %s",
                    row.id, row.type, row.attempts, e.getMessage());
        } catch (NotificationDeliveryException.Rejected | JsonProcessingException e) {
            row.attempts++;
            row.failedAt = now;
            LOG.errorf(
                    "Outbox row %s (%s) refused and parked, it will not be sent again: %s",
                    row.id, row.type, e.getMessage());
        }
    }

    private NotificationEvent event(NotificationOutbox row) throws JsonProcessingException {
        return new NotificationEvent(
                "households:" + row.id,
                row.householdId,
                row.userId,
                row.type,
                objectMapper.readValue(row.payloadJson, PAYLOAD));
    }
}
