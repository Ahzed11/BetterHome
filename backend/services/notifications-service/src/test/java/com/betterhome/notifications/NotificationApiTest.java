package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationPreference;
import com.betterhome.notifications.service.IngestService;
import com.betterhome.notifications.support.InMemoryUsersGateway;
import com.betterhome.notifications.support.RecordingPushSender;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class NotificationApiTest {

    static final String ALICE_SUBJECT = "b2b2b2b2-0000-0000-0000-00000000000a";
    static final String BOB_SUBJECT = "b2b2b2b2-0000-0000-0000-00000000000b";
    static final UUID ALICE = UUID.fromString("c3c3c3c3-0000-0000-0000-00000000000a");
    static final UUID BOB = UUID.fromString("c3c3c3c3-0000-0000-0000-00000000000b");
    static final UUID HOME = UUID.fromString("d4d4d4d4-0000-0000-0000-000000000001");
    static final UUID FLAT = UUID.fromString("d4d4d4d4-0000-0000-0000-000000000002");

    @Inject InMemoryUsersGateway users;
    @Inject RecordingPushSender pushSender;
    @Inject IngestService ingestService;

    @BeforeEach
    @AfterEach
    @Transactional
    void reset() {
        Notification.deleteAll();
        NotificationPreference.deleteAll();
        pushSender.clear();
        users.clear();
        users.add(UUID.fromString(ALICE_SUBJECT), ALICE, "en");
        users.add(UUID.fromString(BOB_SUBJECT), BOB, "fr");
    }

    private String ingest(String key, UUID user, UUID household, String title) {
        return ingestService
                .ingest(
                        new IngestService.Event(
                                key,
                                household,
                                user,
                                "task_assigned",
                                Map.of("taskTitle", title),
                                null))
                .notification()
                .orElseThrow()
                .id
                .toString();
    }

    private static ValidatableResponse list(String query) {
        return given().when().get("/v1/notifications" + query).then();
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void listsOnlyMyInboxNewestFirstAndNeverTheOtherUsersNotifications() {
        ingest("e1", ALICE, HOME, "First");
        ingest("e2", ALICE, HOME, "Second");
        ingest("e3", BOB, HOME, "Bob's");

        list("").statusCode(200)
                .body("$", hasSize(2))
                .body("[0].body", is("\"Second\" is yours."))
                .body("[1].body", is("\"First\" is yours."))
                .body("channel", org.hamcrest.Matchers.everyItem(is("in_app")));
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void anEmptyInboxIsAnEmptyList() {
        list("").statusCode(200).body("$", hasSize(0));
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void filtersByHouseholdAndUnreadOnly() {
        String home = ingest("h1", ALICE, HOME, "Home chore");
        ingest("h2", ALICE, FLAT, "Flat chore");

        list("?householdId=" + FLAT)
                .body("$", hasSize(1))
                .body("[0].householdId", is(FLAT.toString()));

        given().when().post("/v1/notifications/" + home + "/read").then().statusCode(200);
        list("?unreadOnly=true").body("$", hasSize(1)).body("[0].householdId", is(FLAT.toString()));
        list("").body("$", hasSize(2));
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void pagesWithALimitAndABeforeCursorWithoutRepeatsOrGaps() {
        for (int i = 1; i <= 5; i++) {
            ingest("p" + i, ALICE, HOME, "Chore " + i);
        }

        List<String> firstPage = list("?limit=2").body("$", hasSize(2)).extract().path("id");
        List<String> secondPage =
                list("?limit=2&before=" + firstPage.get(1))
                        .body("$", hasSize(2))
                        .extract()
                        .path("id");
        List<String> lastPage =
                list("?limit=2&before=" + secondPage.get(1))
                        .body("$", hasSize(1))
                        .extract()
                        .path("id");

        assertEquals(
                5,
                java.util.stream.Stream.of(firstPage, secondPage, lastPage)
                        .flatMap(List::stream)
                        .distinct()
                        .count());
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void rejectsBadLimitsAndCursorsThatAreNotMine() {
        String bobs = ingest("c1", BOB, HOME, "Bob's");

        list("?limit=0").statusCode(400).body("code", is("bad_request"));
        list("?limit=101").statusCode(400);
        list("?before=" + bobs).statusCode(400);
        list("?before=" + UUID.randomUUID()).statusCode(400);
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void markingReadSetsReadAtOnceAndKeepsTheFirstTime() {
        String id = ingest("r1", ALICE, HOME, "Read me");

        String first =
                given().when()
                        .post("/v1/notifications/" + id + "/read")
                        .then()
                        .statusCode(200)
                        .body("readAt", notNullValue())
                        .extract()
                        .path("readAt");
        given().when()
                .post("/v1/notifications/" + id + "/read")
                .then()
                .statusCode(200)
                .body("readAt", is(first));
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void markAllReadCountsWhatChangedPerHouseholdOrEverywhere() {
        ingest("a1", ALICE, HOME, "One");
        ingest("a2", ALICE, HOME, "Two");
        ingest("a3", ALICE, FLAT, "Three");
        ingest("a4", BOB, HOME, "Bob's");

        given().when()
                .post("/v1/notifications/read-all?householdId=" + HOME)
                .then()
                .statusCode(200)
                .body("updated", is(2));
        given().when().post("/v1/notifications/read-all").then().body("updated", is(1));
        given().when().post("/v1/notifications/read-all").then().body("updated", is(0));
        list("?unreadOnly=true").body("$", hasSize(0));
        assertEquals(
                1L,
                Notification.count("userId = ?1 and readAt is null and channel = 'in_app'", BOB));
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void preferencesStartEnabledAndKeepWhatIChange() {
        given().when()
                .get("/v1/notification-preferences")
                .then()
                .statusCode(200)
                .body("$", hasSize(18))
                .body("enabled", org.hamcrest.Matchers.everyItem(is(true)));

        given().contentType("application/json")
                .body(Map.of("enabled", false))
                .when()
                .put("/v1/notification-preferences/due_reminder/push")
                .then()
                .statusCode(200)
                .body("type", is("due_reminder"))
                .body("channel", is("push"))
                .body("enabled", is(false));
        given().contentType("application/json")
                .body(Map.of("enabled", false))
                .when()
                .put("/v1/notification-preferences/due_reminder/push")
                .then()
                .statusCode(200);

        given().when()
                .get("/v1/notification-preferences")
                .then()
                .body("$", hasSize(18))
                .body("findAll { it.enabled == false }", hasSize(1))
                .body("find { it.enabled == false }.type", is("due_reminder"));

        given().contentType("application/json")
                .body(Map.of("enabled", true))
                .when()
                .put("/v1/notification-preferences/due_reminder/push")
                .then()
                .body("enabled", is(true));
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void preferenceUpdatesRejectUnknownTypesChannelsAndEmptyBodies() {
        given().contentType("application/json")
                .body(Map.of("enabled", false))
                .when()
                .put("/v1/notification-preferences/party/push")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
        given().contentType("application/json")
                .body(Map.of("enabled", false))
                .when()
                .put("/v1/notification-preferences/overdue/email")
                .then()
                .statusCode(400);
        given().contentType("application/json")
                .body(Map.of())
                .when()
                .put("/v1/notification-preferences/overdue/push")
                .then()
                .statusCode(400);
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void aProfileOutageAnswers503() {
        users.setUnavailable(true);

        list("").statusCode(503).body("code", is("service_unavailable"));
        given().when().get("/v1/notification-preferences").then().statusCode(503);
    }
}
