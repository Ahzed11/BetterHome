package com.betterhome.households;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.NotificationDeliveryException;
import com.betterhome.common.NotificationEvent;
import com.betterhome.households.domain.NotificationOutbox;
import com.betterhome.households.notifications.ScriptedNotificationsGateway;
import com.betterhome.households.service.CurrentUserService;
import com.betterhome.households.service.HouseholdService;
import com.betterhome.households.service.OutboxRelay;
import com.betterhome.households.service.OutboxService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The relay itself: claiming, retrying, parking and sending each row once at a time. */
@QuarkusTest
class OutboxRelayTest {

    private static final UUID OWNER_SUBJECT =
            UUID.fromString("88888888-8888-8888-8888-888888888888");

    @Inject OutboxRelay relay;
    @Inject OutboxService outbox;
    @Inject ScriptedNotificationsGateway gateway;
    @Inject TestClock clock;
    @Inject SecurityTestSupport security;
    @Inject CurrentUserService currentUserService;
    @Inject HouseholdService householdService;

    private static final Instant NOW = Instant.parse("2026-10-14T10:00:00Z");
    private UUID householdId;
    private UUID userId;

    @BeforeEach
    void start() {
        gateway.reset();
        clock.fixAt(NOW);
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
        userId =
                security.asUser(
                                OWNER_SUBJECT,
                                () ->
                                        currentUserService.sync(
                                                "relay-owner@example.com", "Re", "L", "en", "UTC"))
                        .id;
        householdId =
                security.asUser(OWNER_SUBJECT, () -> householdService.create("Relay home", "UTC"))
                        .id;
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
    }

    @AfterEach
    void finish() {
        clock.useSystemTime();
        gateway.reset();
    }

    private UUID enqueue(String householdName) {
        return QuarkusTransaction.requiringNew()
                .call(
                        () ->
                                outbox.enqueue(
                                        householdId,
                                        userId,
                                        "invitation",
                                        Map.of("householdName", householdName)));
    }

    private NotificationOutbox row(UUID id) {
        return QuarkusTransaction.requiringNew()
                .call(() -> NotificationOutbox.<NotificationOutbox>findById(id));
    }

    @Test
    void deliversAPendingRowOnceWithAStableKey() {
        UUID id = enqueue("Seneffe");

        assertEquals(1, relay.relayDue(10));
        assertEquals(0, relay.relayDue(10), "a delivered row is not sent again");

        assertEquals(1, gateway.delivered().size());
        assertEquals("households:" + id, gateway.delivered().getFirst().idempotencyKey());
        assertEquals(NOW, row(id).processedAt);
    }

    @Test
    void aTransientFailureBacksOffAndTheRowIsSentOnceTheWaitIsOver() {
        UUID id = enqueue("Seneffe");
        gateway.failNext(new NotificationDeliveryException.Unavailable("down"));

        assertEquals(1, relay.relayDue(10));

        NotificationOutbox failed = row(id);
        assertNull(failed.processedAt);
        assertEquals(1, failed.attempts);
        assertEquals(NOW.plusSeconds(5), failed.availableAt);
        assertEquals(0, relay.relayDue(10), "not before the backoff is over");

        clock.fixAt(NOW.plusSeconds(5));
        assertEquals(1, relay.relayDue(10));
        assertNotNull(row(id).processedAt);
    }

    @Test
    void aRefusedRowIsParkedAndTheNextOneStillGoes() {
        UUID refused = enqueue("Refused");
        enqueue("Fine");
        gateway.failNext(new NotificationDeliveryException.Rejected("bad type"));

        assertEquals(2, relay.relayDue(10));

        assertNotNull(row(refused).failedAt);
        assertEquals(1, gateway.delivered().size());
        clock.fixAt(NOW.plus(Duration.ofHours(1)));
        assertEquals(0, relay.relayDue(10), "a parked row is never tried again");
    }

    @Test
    void anAnswerLostAfterStoringSendsTheSameKeyAgain() {
        UUID id = enqueue("Seneffe");
        gateway.failNextAfterStoring(new NotificationDeliveryException.Unavailable("lost"));

        relay.relayDue(10);
        clock.fixAt(NOW.plusSeconds(5));
        relay.relayDue(10);

        List<NotificationEvent> sent = gateway.delivered();
        assertEquals(2, sent.size(), "at least once");
        assertEquals(sent.get(0).idempotencyKey(), sent.get(1).idempotencyKey());
        assertEquals("households:" + id, sent.get(0).idempotencyKey());
    }

    @Test
    void severalRelaysNeverSendTheSameRowTwice() throws Exception {
        int rows = 30;
        for (int i = 0; i < rows; i++) {
            enqueue("Home " + i);
        }
        gateway.setLatencyMillis(15);

        ExecutorService pool = Executors.newFixedThreadPool(4);
        try {
            List<Future<Integer>> runs =
                    List.of(
                            pool.submit(() -> relay.relayDue(rows)),
                            pool.submit(() -> relay.relayDue(rows)),
                            pool.submit(() -> relay.relayDue(rows)),
                            pool.submit(() -> relay.relayDue(rows)));
            int claimed = 0;
            for (Future<Integer> run : runs) {
                claimed += run.get(60, TimeUnit.SECONDS);
            }
            assertEquals(rows, claimed);
        } finally {
            pool.shutdownNow();
        }

        Set<String> keys = new HashSet<>();
        for (NotificationEvent event : gateway.delivered()) {
            assertTrue(keys.add(event.idempotencyKey()), "sent twice: " + event.idempotencyKey());
        }
        assertEquals(rows, keys.size());
    }
}
