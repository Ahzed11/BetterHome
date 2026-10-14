package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.households.domain.NotificationOutbox;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/** Writes events into the outbox in the caller's transaction; {@link OutboxRelay} sends them. */
@ApplicationScoped
public class OutboxService {

    private final Clock clock;
    private final ObjectMapper objectMapper;

    @Inject
    public OutboxService(Clock clock, ObjectMapper objectMapper) {
        this.clock = clock;
        this.objectMapper = objectMapper;
    }

    /**
     * Queues an event for {@code userId} and returns its id. The payload holds short strings only
     * (ADR 0017), for example {@code taskId} and {@code taskTitle}.
     */
    @Transactional
    public UUID enqueue(UUID householdId, UUID userId, String type, Map<String, String> payload) {
        Instant now = clock.now();
        NotificationOutbox row = new NotificationOutbox();
        row.id = UUID.randomUUID();
        row.householdId = householdId;
        row.userId = userId;
        row.type = type;
        row.payloadJson = json(payload);
        row.createdAt = now;
        row.availableAt = now;
        row.persist();
        return row.id;
    }

    private String json(Map<String, String> payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("A string map cannot be written as JSON", e);
        }
    }
}
