package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.NotificationDeliveryException;
import com.betterhome.common.NotificationEvent;
import com.betterhome.tasks.domain.NotificationOutbox;
import com.betterhome.tasks.notifications.ScriptedNotificationsGateway;
import com.betterhome.tasks.service.OutboxRelay;
import com.betterhome.tasks.service.OutboxService;
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

@QuarkusTest
class OutboxRelayTest {

    private static final Instant NOW = Instant.parse("2026-10-14T10:00:00Z");
    private static final UUID HOUSEHOLD = UUID.randomUUID();
    private static final UUID USER = UUID.randomUUID();

    @Inject OutboxRelay relay;
    @Inject OutboxService outbox;
    @Inject ScriptedNotificationsGateway gateway;
    @Inject TestClock clock;

    @BeforeEach
    void start() {
        gateway.reset();
        clock.fixAt(NOW);
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
    }

    @AfterEach
    void finish() {
        clock.useSystemTime();
        gateway.reset();
    }

    private UUID enqueue(String type, String title) {
        return QuarkusTransaction.requiringNew()
                .call(
                        () ->
                                outbox.enqueue(
                                        HOUSEHOLD,
                                        USER,
                                        type,
                                        Map.of("taskId", "t-1", "taskTitle", title)));
    }

    private NotificationOutbox row(UUID id) {
        return QuarkusTransaction.requiringNew()
                .call(() -> NotificationOutbox.<NotificationOutbox>findById(id));
    }

    @Test
    void deliversAPendingRowOnceWithAStableKeyAndItsPayload() {
        UUID id = enqueue("task_assigned", "Bins");

        assertEquals(1, relay.relayDue(10));
        assertEquals(0, relay.relayDue(10), "a delivered row is not sent again");

        List<NotificationEvent> sent = gateway.delivered();
        assertEquals(1, sent.size());
        NotificationEvent event = sent.getFirst();
        assertEquals("tasks:" + id, event.idempotencyKey());
        assertEquals(HOUSEHOLD, event.householdId());
        assertEquals(USER, event.userId());
        assertEquals("task_assigned", event.type());
        assertEquals("Bins", event.payload().get("taskTitle"));
        assertEquals(NOW, row(id).processedAt);
    }

    @Test
    void aTitleWithQuotesSurvivesTheJourney() {
        enqueue("task_assigned", "The \"big\" clean \\ up");

        relay.relayDue(10);

        assertEquals(
                "The \"big\" clean \\ up",
                gateway.delivered().getFirst().payload().get("taskTitle"));
    }

    @Test
    void aTransientFailureBacksOffAndTheRowIsSentOnceTheWaitIsOver() {
        UUID id = enqueue("task_assigned", "Bins");
        gateway.failNext(new NotificationDeliveryException.Unavailable("down"));

        assertEquals(1, relay.relayDue(10));

        NotificationOutbox failed = row(id);
        assertNull(failed.processedAt);
        assertNull(failed.failedAt);
        assertEquals(1, failed.attempts);
        assertEquals(NOW.plusSeconds(5), failed.availableAt);
        assertEquals(0, relay.relayDue(10), "not before the backoff is over");

        clock.fixAt(NOW.plusSeconds(5));
        assertEquals(1, relay.relayDue(10));
        assertEquals(NOW.plusSeconds(5), row(id).processedAt);
        assertEquals(1, gateway.delivered().size());
    }

    @Test
    void theWaitGrowsWithEveryFailure() {
        UUID id = enqueue("task_assigned", "Bins");
        gateway.failNext(new NotificationDeliveryException.Unavailable("down"));
        gateway.failNext(new NotificationDeliveryException.Unavailable("down"));

        relay.relayDue(10);
        clock.fixAt(NOW.plusSeconds(5));
        relay.relayDue(10);

        assertEquals(2, row(id).attempts);
        assertEquals(NOW.plusSeconds(5).plus(Duration.ofSeconds(10)), row(id).availableAt);
    }

    @Test
    void aRefusedRowIsParkedAndTheNextOneStillGoes() {
        UUID refused = enqueue("task_assigned", "Refused");
        enqueue("task_assigned", "Fine");
        gateway.failNext(new NotificationDeliveryException.Rejected("bad type"));

        assertEquals(2, relay.relayDue(10));

        NotificationOutbox parked = row(refused);
        assertNotNull(parked.failedAt);
        assertNull(parked.processedAt);
        assertEquals(1, parked.attempts);
        assertEquals(1, gateway.delivered().size());
        assertEquals("Fine", gateway.delivered().getFirst().payload().get("taskTitle"));

        clock.fixAt(NOW.plus(Duration.ofHours(1)));
        assertEquals(0, relay.relayDue(10), "a parked row is never tried again");
    }

    @Test
    void anAnswerLostAfterStoringSendsTheSameKeyAgain() {
        UUID id = enqueue("task_assigned", "Bins");
        gateway.failNextAfterStoring(new NotificationDeliveryException.Unavailable("lost"));

        relay.relayDue(10);
        clock.fixAt(NOW.plusSeconds(5));
        relay.relayDue(10);

        List<NotificationEvent> sent = gateway.delivered();
        assertEquals(2, sent.size(), "at least once");
        assertEquals(sent.get(0).idempotencyKey(), sent.get(1).idempotencyKey());
        assertEquals("tasks:" + id, sent.get(0).idempotencyKey());
        assertNotNull(row(id).processedAt);
    }

    @Test
    void anUnreadablePayloadIsParkedInsteadOfBlockingTheQueue() {
        UUID id = UUID.randomUUID();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            NotificationOutbox bad = new NotificationOutbox();
                            bad.id = id;
                            bad.householdId = HOUSEHOLD;
                            bad.userId = USER;
                            bad.type = "task_assigned";
                            bad.payloadJson = "not json";
                            bad.createdAt = NOW.minusSeconds(1);
                            bad.availableAt = NOW.minusSeconds(1);
                            bad.persist();
                        });
        enqueue("task_assigned", "Fine");

        assertEquals(2, relay.relayDue(10));

        assertNotNull(row(id).failedAt);
        assertEquals(1, gateway.delivered().size());
    }

    @Test
    void theLimitBoundsHowManyRowsOneRunSends() {
        for (int i = 0; i < 5; i++) {
            enqueue("task_assigned", "Chore " + i);
        }

        assertEquals(2, relay.relayDue(2));
        assertEquals(2, gateway.delivered().size());
        assertEquals(3, relay.relayDue(10));
    }

    @Test
    void rowsGoOutOldestFirst() {
        enqueue("task_assigned", "First");
        clock.fixAt(NOW.plusSeconds(1));
        enqueue("task_assigned", "Second");

        relay.relayDue(10);

        assertEquals(
                List.of("First", "Second"),
                gateway.delivered().stream().map(e -> e.payload().get("taskTitle")).toList());
    }

    @Test
    void severalRelaysNeverSendTheSameRowTwice() throws Exception {
        int rows = 40;
        for (int i = 0; i < rows; i++) {
            enqueue("task_assigned", "Chore " + i);
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
        assertEquals(
                0,
                (long)
                        QuarkusTransaction.requiringNew()
                                .call(() -> NotificationOutbox.count("processedAt is null")));
    }

    @Test
    void anEventQueuedInARolledBackTransactionIsNeverSent() {
        QuarkusTransaction.begin();
        outbox.enqueue(HOUSEHOLD, USER, "task_assigned", Map.of("taskTitle", "Ghost"));
        QuarkusTransaction.rollback();

        assertEquals(0, relay.relayDue(10));
        assertFalse(
                gateway.delivered().stream()
                        .anyMatch(e -> "Ghost".equals(e.payload().get("taskTitle"))));
        assertEquals(
                0L,
                (long) QuarkusTransaction.requiringNew().call(() -> NotificationOutbox.count()));
    }
}
