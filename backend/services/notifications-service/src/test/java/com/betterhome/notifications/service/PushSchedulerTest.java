package com.betterhome.notifications.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.common.PushSender.Outcome;
import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.support.RecordingPushSender;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The scheduled job hands every due push row to {@link PushDelivery}. */
@QuarkusTest
class PushSchedulerTest {

    @Inject PushScheduler scheduler;
    @Inject RecordingPushSender pushSender;

    @BeforeEach
    @AfterEach
    void reset() {
        QuarkusTransaction.requiringNew().run(() -> Notification.deleteAll());
        pushSender.clear();
    }

    @Test
    void aDuePushRowIsSentWhenTheJobRuns() {
        UUID id = UUID.randomUUID();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            Notification row = new Notification();
                            row.id = id;
                            row.householdId = UUID.randomUUID();
                            row.userId = UUID.randomUUID();
                            row.type = NotificationType.task_assigned;
                            row.channel = Channel.push;
                            row.title = "Title";
                            row.body = "Body";
                            row.payload = Map.of("taskTitle", "Dishes");
                            row.idempotencyKey = "scheduler-" + id;
                            row.createdAt = Instant.parse("2026-11-01T09:00:00Z");
                            row.pushAvailableAt = Instant.parse("2026-11-01T09:00:00Z");
                            row.persist();
                        });
        pushSender.script(Outcome.SENT);

        scheduler.retryPushes();

        assertEquals(1, pushSender.sent().size());
        Instant pushedAt =
                QuarkusTransaction.requiringNew()
                        .call(() -> ((Notification) Notification.findById(id)).pushedAt);
        assertEquals(true, pushedAt != null);
    }
}
