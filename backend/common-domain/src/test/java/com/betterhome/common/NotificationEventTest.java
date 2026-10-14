package com.betterhome.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class NotificationEventTest {

    private static final UUID HOUSEHOLD = UUID.randomUUID();
    private static final UUID USER = UUID.randomUUID();

    @Test
    void keepsItsFields() {
        NotificationEvent event =
                new NotificationEvent(
                        "tasks:1", HOUSEHOLD, USER, "task_assigned", Map.of("taskTitle", "Bins"));

        assertEquals("tasks:1", event.idempotencyKey());
        assertEquals("Bins", event.payload().get("taskTitle"));
    }

    @Test
    void anAbsentPayloadIsEmpty() {
        assertTrue(
                new NotificationEvent("k", HOUSEHOLD, USER, "marked_away", null)
                        .payload()
                        .isEmpty());
    }

    @Test
    void thePayloadIsCopiedSoLaterChangesDoNotReachTheEvent() {
        Map<String, String> payload = new HashMap<>(Map.of("taskTitle", "Bins"));
        NotificationEvent event = new NotificationEvent("k", HOUSEHOLD, USER, "dismissed", payload);

        payload.put("taskTitle", "Changed");

        assertEquals("Bins", event.payload().get("taskTitle"));
    }

    @Test
    void everyIdentifyingFieldIsRequired() {
        assertThrows(
                NullPointerException.class,
                () -> new NotificationEvent(null, HOUSEHOLD, USER, "t", Map.of()));
        assertThrows(
                NullPointerException.class,
                () -> new NotificationEvent("k", null, USER, "t", Map.of()));
        assertThrows(
                NullPointerException.class,
                () -> new NotificationEvent("k", HOUSEHOLD, null, "t", Map.of()));
        assertThrows(
                NullPointerException.class,
                () -> new NotificationEvent("k", HOUSEHOLD, USER, null, Map.of()));
    }
}
