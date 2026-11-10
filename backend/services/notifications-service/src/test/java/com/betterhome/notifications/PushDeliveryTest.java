package com.betterhome.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.Clock;
import com.betterhome.common.RelayBackoff;
import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.domain.PushState;
import com.betterhome.notifications.domain.PushTarget;
import com.betterhome.notifications.service.GotifyPushSender;
import com.betterhome.notifications.service.PushDelivery;
import com.betterhome.notifications.service.PushTargetService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Push rows are retried with backoff against a fake Gotify, with a clock the test moves. */
@QuarkusTest
class PushDeliveryTest {

    private static final UUID ALICE = UUID.fromString("b2b2b2b2-0000-0000-0000-00000000000a");
    private static final String TOKEN = "SecretGotifyToken2";
    private static final Instant START = Instant.parse("2026-11-10T10:00:00Z");

    /** A clock the test sets. */
    private static final class MovableClock implements Clock {
        private volatile Instant now = START;

        @Override
        public Instant now() {
            return now;
        }
    }

    @Inject PushTargetService targets;
    @Inject ObjectMapper json;
    @Inject EntityManager entityManager;

    private final MovableClock clock = new MovableClock();
    private FakeGotifyServer gotify;
    private PushDelivery delivery;

    @BeforeEach
    void start() {
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            Notification.delete("userId", ALICE);
                            PushTarget.deleteAll();
                        });
        gotify = new FakeGotifyServer();
        delivery =
                new PushDelivery(
                        clock,
                        new GotifyPushSender(Optional.of(gotify.url()), targets, json),
                        entityManager,
                        json);
        targets.register(ALICE, TOKEN);
    }

    @AfterEach
    void stop() {
        gotify.close();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            Notification.delete("userId", ALICE);
                            PushTarget.deleteAll();
                        });
    }

    private UUID pendingPush() {
        return QuarkusTransaction.requiringNew()
                .call(
                        () -> {
                            Notification row = new Notification();
                            row.id = UUID.randomUUID();
                            row.householdId = UUID.randomUUID();
                            row.userId = ALICE;
                            row.type = NotificationType.task_assigned;
                            row.channel = Channel.push;
                            row.title = "Dishes assigned to you";
                            row.body = "Remember the dishes tonight";
                            row.payload = java.util.Map.of("taskTitle", "Dishes");
                            row.idempotencyKey = "k-" + row.id;
                            row.createdAt = START;
                            row.pushState = PushState.pending;
                            row.pushAvailableAt = START;
                            row.persist();
                            return row.id;
                        });
    }

    private Notification row(UUID id) {
        return QuarkusTransaction.requiringNew().call(() -> Notification.findById(id));
    }

    @Test
    void aDeliveredPushIsSentOnceAndNeverTriedAgain() {
        UUID id = pendingPush();

        assertTrue(delivery.attempt(id));
        assertEquals(PushState.sent, row(id).pushState);
        assertEquals(1, row(id).pushAttempts);

        clock.now = START.plus(Duration.ofDays(1));
        assertEquals(false, delivery.attempt(id));
        assertEquals(0, delivery.retryDue(10));
        assertEquals(1, gotify.received().size());
    }

    @Test
    void anUnavailableGotifyIsRetriedWithBackoffUntilItAnswers() {
        UUID id = pendingPush();
        gotify.answer(503);

        assertTrue(delivery.attempt(id));
        assertEquals(PushState.pending, row(id).pushState);
        assertEquals(START.plus(RelayBackoff.delay(1)), row(id).pushAvailableAt);

        clock.now = START.plus(RelayBackoff.delay(1)).minusMillis(1);
        assertEquals(0, delivery.retryDue(10), "not due yet");
        assertEquals(1, gotify.received().size());

        clock.now = START.plus(RelayBackoff.delay(1));
        assertEquals(1, delivery.retryDue(10));
        assertEquals(2, row(id).pushAttempts);
        assertEquals(clock.now.plus(RelayBackoff.delay(2)), row(id).pushAvailableAt);

        gotify.answer(200);
        clock.now = clock.now.plus(RelayBackoff.delay(2));
        assertEquals(1, delivery.retryDue(10));
        assertEquals(PushState.sent, row(id).pushState);
        assertEquals(3, row(id).pushAttempts);
        assertEquals(3, gotify.received().size());
    }

    @Test
    void aConnectionErrorAndATimeoutShapedFailureAreRetriedToo() {
        UUID id = pendingPush();
        gotify.answer(-1);

        delivery.attempt(id);

        assertEquals(PushState.pending, row(id).pushState);
    }

    @Test
    void aRefusedTokenIsNeverRetriedAndTheTargetIsRemoved() {
        UUID id = pendingPush();
        gotify.answer(401);

        delivery.attempt(id);

        assertEquals(PushState.refused, row(id).pushState);
        assertEquals(Optional.empty(), targets.tokenOf(ALICE));
        clock.now = START.plus(Duration.ofDays(1));
        assertEquals(0, delivery.retryDue(10));
        assertEquals(1, gotify.received().size());
    }

    @Test
    void aRefusedMessageIsNeverRetried() {
        UUID id = pendingPush();
        gotify.answer(400);

        delivery.attempt(id);

        assertEquals(PushState.refused, row(id).pushState);
        assertEquals(Optional.of(TOKEN), targets.tokenOf(ALICE));
        clock.now = START.plus(Duration.ofDays(1));
        assertEquals(0, delivery.retryDue(10));
    }

    @Test
    void aUserWithoutATargetIsSkippedNotRetried() {
        UUID id = pendingPush();
        targets.remove(ALICE);

        delivery.attempt(id);

        assertEquals(PushState.skipped, row(id).pushState);
        assertEquals(0, gotify.received().size());
    }

    @Test
    void aPushIsGivenUpAfterTheLastAttempt() {
        UUID id = pendingPush();
        gotify.answer(500);

        for (int attempt = 1; attempt <= 10; attempt++) {
            clock.now = clock.now.plus(Duration.ofMinutes(15));
            assertEquals(1, delivery.retryDue(10), "attempt " + attempt);
        }

        assertEquals(PushState.gave_up, row(id).pushState);
        assertEquals(10, row(id).pushAttempts);
        assertEquals(null, row(id).pushAvailableAt);
        clock.now = clock.now.plus(Duration.ofDays(1));
        assertEquals(0, delivery.retryDue(10));
        assertEquals(10, gotify.received().size());
    }

    @Test
    void retryDueSendsOldestFirstAndStopsAtTheLimit() {
        List<UUID> ids = new ArrayList<>();
        for (int i = 0; i < 3; i++) {
            ids.add(pendingPush());
        }

        assertEquals(2, delivery.retryDue(2));

        assertEquals(2, gotify.received().size());
        assertEquals(1, delivery.retryDue(10));
        assertEquals(3, gotify.received().size());
    }

    @Test
    void replicasNeverPushTheSameRowTwice() throws Exception {
        UUID id = pendingPush();
        ExecutorService pool = Executors.newFixedThreadPool(8);
        try {
            List<Future<Boolean>> results = new ArrayList<>();
            for (int i = 0; i < 8; i++) {
                results.add(pool.submit(() -> delivery.attempt(id)));
            }
            long tried = 0;
            for (Future<Boolean> result : results) {
                if (result.get()) {
                    tried++;
                }
            }
            assertEquals(1L, tried);
        } finally {
            pool.shutdownNow();
        }
        assertEquals(1, gotify.received().size());
    }
}
