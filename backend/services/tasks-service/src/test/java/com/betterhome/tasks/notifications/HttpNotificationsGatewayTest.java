package com.betterhome.tasks.notifications;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.NotificationDeliveryException;
import com.betterhome.common.NotificationEvent;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

@QuarkusTest
@QuarkusTestResource(value = FakeNotificationsServer.class, restrictToAnnotatedClass = true)
class HttpNotificationsGatewayTest {

    private static final UUID HOUSEHOLD = UUID.randomUUID();
    private static final UUID USER = UUID.randomUUID();
    private static final NotificationEvent EVENT =
            new NotificationEvent(
                    "tasks:7d1f",
                    HOUSEHOLD,
                    USER,
                    "task_assigned",
                    Map.of("taskId", "t-1", "taskTitle", "Take out the bins"));

    @Inject HttpNotificationsGateway gateway;

    @BeforeEach
    @AfterEach
    void reset() {
        FakeNotificationsServer.CALLS.clear();
        FakeNotificationsServer.ingestStatus = 201;
    }

    @Test
    void postsTheEventWithTheServiceToken() {
        gateway.deliver(EVENT);

        FakeNotificationsServer.Call call = FakeNotificationsServer.CALLS.get(0);
        assertEquals("/v1/internal/notifications", call.path());
        assertEquals("Bearer " + FakeNotificationsServer.TOKEN, call.authorization());
        assertTrue(call.body().contains("\"idempotencyKey\":\"tasks:7d1f\""));
        assertTrue(call.body().contains("\"householdId\":\"" + HOUSEHOLD + "\""));
        assertTrue(call.body().contains("\"userId\":\"" + USER + "\""));
        assertTrue(call.body().contains("\"type\":\"task_assigned\""));
        assertTrue(call.body().contains("\"taskTitle\":\"Take out the bins\""));
    }

    @Test
    void aStoredOrSuppressedAnswerCountsAsDelivered() {
        FakeNotificationsServer.ingestStatus = 200;

        assertDoesNotThrow(() -> gateway.deliver(EVENT));
    }

    @ParameterizedTest
    @ValueSource(ints = {400, 404, 409, 422})
    void aClientErrorAboutTheEventIsRefusedForGood(int status) {
        FakeNotificationsServer.ingestStatus = status;

        assertThrows(NotificationDeliveryException.Rejected.class, () -> gateway.deliver(EVENT));
    }

    @ParameterizedTest
    @ValueSource(ints = {401, 403, 429, 500, 502, 503})
    void tokenProblemsThrottlingAndServerErrorsAreWorthRetrying(int status) {
        FakeNotificationsServer.ingestStatus = status;

        assertThrows(NotificationDeliveryException.Unavailable.class, () -> gateway.deliver(EVENT));
    }

    @Test
    void aDroppedConnectionIsWorthRetrying() {
        FakeNotificationsServer.ingestStatus = -1;

        assertThrows(NotificationDeliveryException.Unavailable.class, () -> gateway.deliver(EVENT));
    }
}
