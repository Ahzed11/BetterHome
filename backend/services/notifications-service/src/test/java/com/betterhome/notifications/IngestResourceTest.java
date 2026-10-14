package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import com.betterhome.common.PushSender.PushMessage;
import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationPreference;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.service.PreferenceService;
import com.betterhome.notifications.support.InMemoryUsersGateway;
import com.betterhome.notifications.support.RecordingPushSender;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
@TestSecurity(user = "tasks-service", roles = "service")
class IngestResourceTest {

    private static final UUID HOUSEHOLD = UUID.fromString("a1a1a1a1-0000-0000-0000-000000000001");
    private static final UUID FRENCH_USER = UUID.fromString("a1a1a1a1-0000-0000-0000-0000000000f1");
    private static final UUID ENGLISH_USER =
            UUID.fromString("a1a1a1a1-0000-0000-0000-0000000000e1");

    @Inject InMemoryUsersGateway users;
    @Inject RecordingPushSender pushSender;
    @Inject PreferenceService preferences;

    @BeforeEach
    @AfterEach
    @Transactional
    void reset() {
        Notification.deleteAll();
        NotificationPreference.deleteAll();
        pushSender.clear();
        users.clear();
        users.add(UUID.randomUUID(), FRENCH_USER, "fr");
        users.add(UUID.randomUUID(), ENGLISH_USER, "en");
    }

    private static Map<String, Object> event(String key, UUID user, String type) {
        Map<String, Object> body = new HashMap<>();
        body.put("idempotencyKey", key);
        body.put("householdId", HOUSEHOLD);
        body.put("userId", user);
        body.put("type", type);
        body.put("payload", Map.of("taskId", UUID.randomUUID().toString(), "taskTitle", "Dishes"));
        return body;
    }

    private io.restassured.response.ValidatableResponse post(Map<String, Object> body) {
        return given().contentType("application/json")
                .body(body)
                .when()
                .post("/v1/internal/notifications")
                .then();
    }

    @Test
    void storesAnInboxNotificationInTheRecipientsLanguage() {
        post(event("k-fr", FRENCH_USER, "task_assigned"))
                .statusCode(201)
                .body("outcome", is("created"))
                .body("notification.channel", is("in_app"))
                .body("notification.title", is("Nouvelle tâche"))
                .body("notification.body", is("« Dishes » est pour vous."))
                .body("notification.readAt", nullValue());
        post(event("k-en", ENGLISH_USER, "task_assigned"))
                .statusCode(201)
                .body("notification.title", is("New chore"))
                .body("notification.body", is("\"Dishes\" is yours."));
    }

    @Test
    void everyTypeOfSpecSection5IsAccepted() {
        for (NotificationType type : NotificationType.values()) {
            Map<String, Object> body = event("k-" + type, ENGLISH_USER, type.name());
            body.put("payload", Map.of("taskTitle", "Dishes", "householdName", "Home"));
            post(body).statusCode(201).body("notification.type", is(type.name()));
        }
    }

    @Test
    void handsThePushRowToThePushSenderOnlyAfterItIsStored() {
        post(event("k-push", FRENCH_USER, "due_reminder")).statusCode(201);

        List<PushMessage> sent = pushSender.sent();
        assertEquals(1, sent.size());
        PushMessage message = sent.get(0);
        assertEquals(FRENCH_USER.toString(), message.userId());
        assertEquals("due_reminder", message.type());
        assertEquals("Rappel", message.title());
        assertEquals(1L, countRows("k-push", Channel.push));
        assertEquals(1L, countRows("k-push", Channel.in_app));
    }

    @Test
    void repeatingAKeyChangesNothingAndReturnsTheExistingNotification() {
        String firstId =
                post(event("k-dup", FRENCH_USER, "task_assigned"))
                        .statusCode(201)
                        .extract()
                        .path("notification.id");

        post(event("k-dup", FRENCH_USER, "task_assigned"))
                .statusCode(200)
                .body("outcome", is("duplicate"))
                .body("notification.id", is(firstId));

        assertEquals(1, pushSender.sent().size());
        assertEquals(2L, Notification.count("idempotencyKey", "k-dup"));
    }

    @Test
    void concurrentDeliveriesOfTheSameEventStoreItOnce() throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(8);
        try {
            List<Future<Integer>> results = new ArrayList<>();
            for (int i = 0; i < 8; i++) {
                results.add(
                        pool.submit(
                                () ->
                                        post(event("k-race", ENGLISH_USER, "task_assigned"))
                                                .extract()
                                                .statusCode()));
            }
            long created = 0;
            for (Future<Integer> result : results) {
                if (result.get() == 201) {
                    created++;
                }
            }
            assertEquals(1L, created);
        } finally {
            pool.shutdownNow();
        }
        assertEquals(2L, Notification.count("idempotencyKey", "k-race"));
        assertEquals(1, pushSender.sent().size());
    }

    @Test
    void unknownTypesAreRejected() {
        post(event("k-bad", ENGLISH_USER, "party_time"))
                .statusCode(400)
                .body("code", is("bad_request"));
        assertEquals(0L, Notification.count());
    }

    @Test
    void invalidEventsAreRejectedAndNothingIsStored() {
        Map<String, Object> noKey = event("", ENGLISH_USER, "task_assigned");
        post(noKey).statusCode(400);

        Map<String, Object> noUser = event("k-nouser", ENGLISH_USER, "task_assigned");
        noUser.remove("userId");
        post(noUser).statusCode(400);

        Map<String, Object> missingTitle = event("k-notitle", ENGLISH_USER, "task_assigned");
        missingTitle.put("payload", Map.of("taskId", "x"));
        post(missingTitle).statusCode(400).body("code", is("bad_request"));

        Map<String, Object> longValue = event("k-long", ENGLISH_USER, "task_assigned");
        longValue.put("payload", Map.of("taskTitle", "x".repeat(201)));
        post(longValue).statusCode(400);

        Map<String, Object> manyEntries = event("k-many", ENGLISH_USER, "task_assigned");
        Map<String, String> payload = new HashMap<>();
        for (int i = 0; i < 11; i++) {
            payload.put("key" + i, "v");
        }
        payload.put("taskTitle", "Dishes");
        manyEntries.put("payload", payload);
        post(manyEntries).statusCode(400);

        Map<String, Object> noPayloadAtAll = event("k-nopayload", ENGLISH_USER, "task_assigned");
        noPayloadAtAll.remove("payload");
        post(noPayloadAtAll).statusCode(400);

        assertEquals(0L, Notification.count());
        assertEquals(0, pushSender.sent().size());
    }

    @Test
    void aTypeWithoutRequiredKeysAcceptsNoPayload() {
        Map<String, Object> body = event("k-away", ENGLISH_USER, "marked_away");
        body.remove("payload");

        post(body).statusCode(201).body("notification.title", is("Marked away"));
    }

    @Test
    void disablingAPushTypeKeepsTheInboxButSendsNoPush() {
        preferences.set(ENGLISH_USER, "task_assigned", "push", false);

        post(event("k-nopush", ENGLISH_USER, "task_assigned")).statusCode(201);

        assertEquals(0, pushSender.sent().size());
        assertEquals(1L, countRows("k-nopush", Channel.in_app));
        assertEquals(0L, countRows("k-nopush", Channel.push));
    }

    @Test
    void disablingTheInboxStillPushes() {
        preferences.set(ENGLISH_USER, "task_assigned", "in_app", false);

        post(event("k-noinbox", ENGLISH_USER, "task_assigned"))
                .statusCode(201)
                .body("notification.channel", is("push"));

        assertEquals(1, pushSender.sent().size());
    }

    @Test
    void disablingEveryChannelOfATypeCreatesNothing() {
        preferences.set(ENGLISH_USER, "overdue", "push", false);
        preferences.set(ENGLISH_USER, "overdue", "in_app", false);

        post(event("k-off", ENGLISH_USER, "overdue"))
                .statusCode(200)
                .body("outcome", is("suppressed"))
                .body("notification", nullValue());

        assertEquals(0L, Notification.count());
        assertEquals(0, pushSender.sent().size());
        post(event("k-on", ENGLISH_USER, "task_assigned")).statusCode(201);
    }

    @Test
    void usersUnknownToHouseholdsGetTheHintedLanguageOrEnglish() {
        UUID stranger = UUID.randomUUID();
        Map<String, Object> hinted = event("k-hint", stranger, "task_assigned");
        hinted.put("localeHint", "fr");
        post(hinted).statusCode(201).body("notification.title", is("Nouvelle tâche"));

        Map<String, Object> unsupported = event("k-hint2", stranger, "task_assigned");
        unsupported.put("localeHint", "de");
        post(unsupported).statusCode(201).body("notification.title", is("New chore"));

        post(event("k-nohint", stranger, "task_assigned"))
                .statusCode(201)
                .body("notification.title", is("New chore"));
    }

    @Test
    void theHouseholdsProfileBeatsTheHint() {
        Map<String, Object> body = event("k-profile", ENGLISH_USER, "task_assigned");
        body.put("localeHint", "fr");

        post(body).statusCode(201).body("notification.title", is("New chore"));
    }

    @Test
    void aHouseholdsOutageAnswers503StoresNothingAndTheRetrySucceeds() {
        users.setUnavailable(true);

        post(event("k-503", ENGLISH_USER, "task_assigned"))
                .statusCode(503)
                .body("code", is("service_unavailable"));

        assertEquals(0L, Notification.count());
        assertEquals(0, pushSender.sent().size());
        users.setUnavailable(false);
        post(event("k-503", ENGLISH_USER, "task_assigned")).statusCode(201);
        assertFalse(pushSender.sent().isEmpty());
    }

    private static long countRows(String key, Channel channel) {
        return Notification.count("idempotencyKey = ?1 and channel = ?2", key, channel);
    }
}
