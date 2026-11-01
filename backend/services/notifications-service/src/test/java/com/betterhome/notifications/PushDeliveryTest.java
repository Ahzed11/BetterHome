package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.PushSender.Outcome;
import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationPreference;
import com.betterhome.notifications.service.PushDelivery;
import com.betterhome.notifications.support.InMemoryUsersGateway;
import com.betterhome.notifications.support.RecordingPushSender;
import com.betterhome.notifications.support.TestClock;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** A push that Gotify could not take is tried again, once at a time, and never twice when sent. */
@QuarkusTest
@TestSecurity(user = "tasks-service", roles = "service")
class PushDeliveryTest {

    private static final Instant NOW = Instant.parse("2026-11-01T10:00:00Z");
    private static final UUID HOUSEHOLD = UUID.fromString("d1d1d1d1-0000-0000-0000-000000000001");
    private static final UUID USER = UUID.fromString("d1d1d1d1-0000-0000-0000-0000000000e1");

    @Inject InMemoryUsersGateway users;
    @Inject RecordingPushSender pushSender;
    @Inject TestClock clock;
    @Inject PushDelivery delivery;
    @Inject EntityManager entityManager;

    @BeforeEach
    @AfterEach
    void reset() {
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            Notification.deleteAll();
                            NotificationPreference.deleteAll();
                        });
        pushSender.clear();
        users.clear();
        users.add(UUID.randomUUID(), USER, "en");
        clock.fixAt(NOW);
    }

    @AfterEach
    void useSystemTime() {
        clock.useSystemTime();
    }

    private void ingest(String key) {
        given().contentType("application/json")
                .body(
                        Map.of(
                                "idempotencyKey",
                                key,
                                "householdId",
                                HOUSEHOLD,
                                "userId",
                                USER,
                                "type",
                                "task_assigned",
                                "payload",
                                Map.of(
                                        "taskId",
                                        UUID.randomUUID().toString(),
                                        "taskTitle",
                                        "Dishes")))
                .when()
                .post("/v1/internal/notifications")
                .then()
                .statusCode(
                        org.hamcrest.Matchers.anyOf(
                                org.hamcrest.Matchers.is(200), org.hamcrest.Matchers.is(201)));
    }

    private Notification pushRow() {
        return QuarkusTransaction.requiringNew()
                .call(
                        () -> {
                            List<Notification> rows = Notification.list("channel", Channel.push);
                            assertEquals(1, rows.size());
                            Notification row = rows.get(0);
                            entityManager.detach(row);
                            return row;
                        });
    }

    @Test
    void aPushTheServerTookIsRecordedAndNeverSentAgain() {
        ingest("k-sent");

        Notification row = pushRow();
        assertNotNull(row.pushedAt);
        assertNull(row.pushFailedAt);
        assertEquals(0, row.pushAttempts);

        clock.fixAt(NOW.plus(Duration.ofHours(1)));
        assertEquals(0, delivery.retryDue(10));
        assertEquals(1, pushSender.sent().size());
    }

    @Test
    void aPushTheServerCouldNotTakeIsRetriedAfterTheBackoff() {
        pushSender.script(Outcome.RETRY, Outcome.RETRY);

        ingest("k-retry");

        Notification first = pushRow();
        assertNull(first.pushedAt);
        assertEquals(1, first.pushAttempts);
        assertEquals(NOW.plusSeconds(5), first.pushAvailableAt);
        assertEquals(1, pushSender.sent().size());

        clock.fixAt(NOW.plusSeconds(4));
        assertEquals(0, delivery.retryDue(10), "not due yet");

        clock.fixAt(NOW.plusSeconds(5));
        assertEquals(1, delivery.retryDue(10));
        Notification second = pushRow();
        assertNull(second.pushedAt);
        assertEquals(2, second.pushAttempts);
        assertEquals(NOW.plusSeconds(15), second.pushAvailableAt);

        clock.fixAt(NOW.plusSeconds(15));
        assertEquals(1, delivery.retryDue(10));
        Notification third = pushRow();
        assertEquals(NOW.plusSeconds(15), third.pushedAt);
        assertEquals(3, pushSender.sent().size());

        clock.fixAt(NOW.plus(Duration.ofHours(1)));
        assertEquals(0, delivery.retryDue(10));
        assertEquals(3, pushSender.sent().size());
    }

    @Test
    void anUndeliverablePushIsParkedAndNeverRetried() {
        pushSender.script(Outcome.UNDELIVERABLE);

        ingest("k-final");

        Notification row = pushRow();
        assertEquals(NOW, row.pushFailedAt);
        assertNull(row.pushedAt);

        clock.fixAt(NOW.plus(Duration.ofHours(1)));
        assertEquals(0, delivery.retryDue(10));
        assertEquals(1, pushSender.sent().size());
    }

    @Test
    void aPushGivesUpAfterTheLastAttempt() {
        Outcome[] alwaysFailing = new Outcome[20];
        java.util.Arrays.fill(alwaysFailing, Outcome.RETRY);
        pushSender.script(alwaysFailing);

        ingest("k-giveup");
        for (int i = 0; i < 20 && pushRow().pushFailedAt == null; i++) {
            clock.fixAt(pushRow().pushAvailableAt);
            delivery.retryDue(10);
        }

        Notification row = pushRow();
        assertNotNull(row.pushFailedAt);
        assertEquals(10, row.pushAttempts);
        assertEquals(10, pushSender.sent().size());
    }

    @Test
    void aRepeatedEventNeverPushesAgainWhileAnAttemptIsPending() {
        pushSender.script(Outcome.RETRY);

        ingest("k-dup");
        ingest("k-dup");

        assertEquals(1, pushSender.sent().size());
        assertEquals(1, pushRow().pushAttempts);
    }

    @Test
    void replicasNeverSendTheSameRowTwice() throws Exception {
        pushSender.script(Outcome.RETRY);
        ingest("k-race");
        clock.fixAt(NOW.plusSeconds(5));

        ExecutorService pool = Executors.newFixedThreadPool(4);
        try {
            List<Future<Integer>> runs =
                    java.util.stream.IntStream.range(0, 4)
                            .mapToObj(i -> pool.submit(() -> delivery.retryDue(10)))
                            .toList();
            int claimed = 0;
            for (Future<Integer> run : runs) {
                claimed += run.get();
            }
            assertEquals(1, claimed);
        } finally {
            pool.shutdownNow();
        }
        assertEquals(2, pushSender.sent().size());
    }

    @Test
    void onlyPushRowsCarryDeliveryState() {
        ingest("k-schema");
        Notification inApp =
                QuarkusTransaction.requiringNew()
                        .call(
                                () ->
                                        Notification.<Notification>list("channel", Channel.in_app)
                                                .get(0));

        assertEquals(0, inApp.pushAttempts);
        assertNull(inApp.pushAvailableAt);

        PersistenceException refused =
                assertThrows(
                        PersistenceException.class,
                        () ->
                                QuarkusTransaction.requiringNew()
                                        .run(
                                                () -> {
                                                    Notification row =
                                                            Notification.findById(inApp.id);
                                                    row.pushAvailableAt = NOW;
                                                    entityManager.flush();
                                                }));
        assertTrue(refused.getMessage() != null);
    }
}
