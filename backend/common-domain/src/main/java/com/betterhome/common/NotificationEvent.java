package com.betterhome.common;

import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * An event for notifications-service (ADR 0017): who is told, what happened and the short strings
 * its message needs. The idempotency key identifies the event across retries, for example {@code
 * tasks:<outbox row id>}.
 */
public record NotificationEvent(
        String idempotencyKey,
        UUID householdId,
        UUID userId,
        String type,
        Map<String, String> payload) {

    public NotificationEvent {
        Objects.requireNonNull(idempotencyKey, "idempotencyKey");
        Objects.requireNonNull(householdId, "householdId");
        Objects.requireNonNull(userId, "userId");
        Objects.requireNonNull(type, "type");
        payload = payload == null ? Map.of() : Map.copyOf(payload);
    }
}
