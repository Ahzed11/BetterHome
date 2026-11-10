package com.betterhome.notifications.scheduler;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.domain.PushState;
import com.betterhome.notifications.support.RecordingPushSender;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

/** The periodic job hands every due pending push to the delivery. */
@QuarkusTest
class PushRetrySchedulerTest {

    private static final UUID USER = UUID.fromString("b3b3b3b3-0000-0000-0000-00000000000a");

    @Inject PushRetryScheduler scheduler;
    @Inject RecordingPushSender pushSender;

    @AfterEach
    void clean() {
        pushSender.clear();
        QuarkusTransaction.requiringNew().run(() -> Notification.delete("userId", USER));
    }

    @Test
    void aDuePendingPushIsSentWhenTheJobRuns() {
        UUID id =
                QuarkusTransaction.requiringNew()
                        .call(
                                () -> {
                                    Notification row = new Notification();
                                    row.id = UUID.randomUUID();
                                    row.householdId = UUID.randomUUID();
                                    row.userId = USER;
                                    row.type = NotificationType.overdue;
                                    row.channel = Channel.push;
                                    row.title = "Overdue";
                                    row.body = "Dishes are overdue";
                                    row.payload = Map.of("taskTitle", "Dishes");
                                    row.idempotencyKey = "scheduler-" + row.id;
                                    row.createdAt = Instant.parse("2026-01-01T00:00:00Z");
                                    row.pushState = PushState.pending;
                                    row.pushAvailableAt = Instant.parse("2026-01-01T00:00:00Z");
                                    row.persist();
                                    return row.id;
                                });

        scheduler.retryPushes();

        assertEquals(1, pushSender.sent().size());
        assertEquals(
                PushState.sent,
                QuarkusTransaction.requiringNew()
                        .call(() -> Notification.<Notification>findById(id).pushState));
    }
}
