package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationPreference;
import com.betterhome.notifications.service.IngestService;
import com.betterhome.notifications.support.InMemoryUsersGateway;
import com.betterhome.notifications.support.RecordingPushSender;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Who may call what. Alice owns the data; Bob is another user with a profile; Carol authenticates
 * but has no profile in households; the service account may only ingest.
 */
@QuarkusTest
class NotificationAuthorizationTest {

    private static final String ALICE_SUBJECT = "e5e5e5e5-0000-0000-0000-00000000000a";
    private static final String BOB_SUBJECT = "e5e5e5e5-0000-0000-0000-00000000000b";
    private static final String CAROL_SUBJECT = "e5e5e5e5-0000-0000-0000-00000000000c";
    private static final UUID ALICE = UUID.fromString("f6f6f6f6-0000-0000-0000-00000000000a");
    private static final UUID BOB = UUID.fromString("f6f6f6f6-0000-0000-0000-00000000000b");
    private static final UUID HOME = UUID.fromString("07070707-0000-0000-0000-000000000001");

    @Inject InMemoryUsersGateway users;
    @Inject RecordingPushSender pushSender;
    @Inject IngestService ingestService;

    private UUID alicesNotification;

    @AfterEach
    void clean() {
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            Notification.deleteAll();
                            NotificationPreference.deleteAll();
                        });
        pushSender.clear();
        users.clear();
    }

    @BeforeEach
    void seed() {
        clean();
        users.add(UUID.fromString(ALICE_SUBJECT), ALICE, "en");
        users.add(UUID.fromString(BOB_SUBJECT), BOB, "en");
        alicesNotification =
                ingestService
                        .ingest(
                                new IngestService.Event(
                                        "auth-1",
                                        HOME,
                                        ALICE,
                                        "task_assigned",
                                        Map.of("taskTitle", "Dishes"),
                                        null))
                        .notification()
                        .orElseThrow()
                        .id;
    }

    private static ValidatableResponse getInbox() {
        return given().when().get("/v1/notifications").then();
    }

    private ValidatableResponse markRead() {
        return given().when().post("/v1/notifications/" + alicesNotification + "/read").then();
    }

    private static ValidatableResponse markAllRead() {
        return given().when().post("/v1/notifications/read-all").then();
    }

    private static ValidatableResponse getPreferences() {
        return given().when().get("/v1/notification-preferences").then();
    }

    private static ValidatableResponse putPreference() {
        return given().contentType("application/json")
                .body(Map.of("enabled", false))
                .when()
                .put("/v1/notification-preferences/task_assigned/in_app")
                .then();
    }

    private static ValidatableResponse ingest() {
        return given().contentType("application/json")
                .body(
                        Map.of(
                                "idempotencyKey",
                                "auth-ingest",
                                "householdId",
                                HOME,
                                "userId",
                                ALICE,
                                "type",
                                "task_assigned",
                                "payload",
                                Map.of("taskTitle", "Dishes")))
                .when()
                .post("/v1/internal/notifications")
                .then();
    }

    private Notification stored() {
        return Notification.<Notification>findById(alicesNotification);
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void theOwnerReadsAndChangesTheirOwnData() {
        getInbox()
                .statusCode(200)
                .body("$", hasSize(1))
                .body("[0].id", is(alicesNotification.toString()));
        markRead().statusCode(200);
        markAllRead().statusCode(200);
        getPreferences().statusCode(200);
        putPreference().statusCode(200);
    }

    @Test
    @TestSecurity(
            user = ALICE_SUBJECT,
            roles = {"member", "admin"})
    void householdAdminsAreOrdinaryUsersHere() {
        getInbox().statusCode(200).body("$", hasSize(1));
        ingest().statusCode(403);
    }

    @Test
    @TestSecurity(user = BOB_SUBJECT, roles = "member")
    void anotherUserSeesNothingOfAlicesAndCannotChangeIt() {
        getInbox().statusCode(200).body("$", hasSize(0));
        markRead().statusCode(404).body("code", is("not_found"));
        assertNull(stored().readAt);

        markAllRead().statusCode(200).body("updated", is(0));
        assertNull(stored().readAt);

        putPreference().statusCode(200);
        assertEquals(0L, NotificationPreference.count("userId", ALICE));
        assertEquals(1L, NotificationPreference.count("userId", BOB));
    }

    @Test
    @TestSecurity(user = BOB_SUBJECT, roles = "member")
    void aNotificationThatDoesNotExistLooksTheSameAsSomeoneElses() {
        String missing =
                given().when()
                        .post("/v1/notifications/" + UUID.randomUUID() + "/read")
                        .then()
                        .statusCode(404)
                        .extract()
                        .path("message");
        String foreign =
                given().when()
                        .post("/v1/notifications/" + alicesNotification + "/read")
                        .then()
                        .statusCode(404)
                        .extract()
                        .path("message");

        assertEquals(missing, foreign);
    }

    @Test
    @TestSecurity(user = CAROL_SUBJECT, roles = "member")
    void aUserWithoutAProfileIsForbiddenEverywhere() {
        getInbox().statusCode(403);
        markRead().statusCode(403);
        markAllRead().statusCode(403);
        getPreferences().statusCode(403);
        putPreference().statusCode(403);
        ingest().statusCode(403);
    }

    @Test
    @TestSecurity(user = "0a0a0a0a-0000-0000-0000-0000000000aa", roles = "service")
    void theServiceAccountCanIngestButHasNoInboxOfItsOwn() {
        ingest().statusCode(201);

        getInbox().statusCode(403);
        markRead().statusCode(403);
        markAllRead().statusCode(403);
        getPreferences().statusCode(403);
        putPreference().statusCode(403);
        assertNull(stored().readAt);
    }

    @Test
    void anonymousCallersAreRejectedEverywhere() {
        getInbox().statusCode(401);
        markRead().statusCode(401);
        markAllRead().statusCode(401);
        getPreferences().statusCode(401);
        putPreference().statusCode(401);
        ingest().statusCode(401);
        assertEquals(2L, Notification.count());
    }
}
