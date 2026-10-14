package com.betterhome.tasks;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.hasSize;

import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.HouseholdSettings;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The templates, recurrence and task endpoints over HTTP. The contract filter installed for every
 * test of this service checks each answer (status, headers, body, no undocumented field) against
 * the committed OpenAPI document, so these calls prove the real answers equal the documented ones.
 */
@QuarkusTest
class TasksHttpTest {

    private static final UUID HOUSEHOLD = UUID.fromString("dddddddd-bbbb-cccc-dddd-eeeeeeeeeeee");
    private static final String ADMIN_SUBJECT = "11111111-1111-1111-1111-111111111111";
    private static final String MEMBER_SUBJECT = "22222222-2222-2222-2222-222222222222";
    private static final String OUTSIDER_SUBJECT = "33333333-3333-3333-3333-333333333333";
    private static final UUID ADMIN_USER = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    private static final String TEMPLATES = "/v1/households/" + HOUSEHOLD + "/templates";
    private static final String TASKS = "/v1/households/" + HOUSEHOLD + "/tasks";

    @Inject InMemoryMembershipGateway membershipGateway;

    @BeforeEach
    void seedMembers() {
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, UUID.fromString(ADMIN_SUBJECT), true, false, 1),
                        new MemberView(
                                MEMBER_USER, UUID.fromString(MEMBER_SUBJECT), false, false, 2)));
        membershipGateway.putSettings(
                HOUSEHOLD, new HouseholdSettings("UTC", 0, LocalTime.of(8, 0)));
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void adminManagesTemplatesRecurrencesAndTheLifeOfATask() {
        String templateId = createTemplate("Bins");
        json().body(Map.of("points", 7))
                .patch(TEMPLATES + "/" + templateId)
                .then()
                .statusCode(200)
                .body("points", is(7));
        json().get(TEMPLATES).then().statusCode(200);

        json().body(
                        Map.of(
                                "rrule", "FREQ=DAILY",
                                "assignmentMode", "round_robin",
                                "startsAt", Instant.now().plusSeconds(3600).toString()))
                .put(TEMPLATES + "/" + templateId + "/recurrence")
                .then()
                .statusCode(200);
        json().get(TEMPLATES + "/" + templateId + "/recurrence").then().statusCode(200);

        String openId = createOpenTask(templateId);
        json().get(TASKS + "?status=open").then().statusCode(200).body("$", hasSize(1));
        json().get(TASKS + "?mine=true").then().statusCode(200);
        json().post(TASKS + "/" + openId + "/complete").then().statusCode(200);
        json().body(Map.of("reason", "Not actually done"))
                .post(TASKS + "/" + openId + "/revert")
                .then()
                .statusCode(200);

        String reassignedId = createOpenTask(templateId);
        json().post(TASKS + "/" + reassignedId + "/reassign").then().statusCode(200);
        json().post(TASKS + "/" + reassignedId + "/dismiss").then().statusCode(200);

        json().body(Map.of("templateId", templateId))
                .post(TASKS + "/manual")
                .then()
                .statusCode(201);
        json().post(TEMPLATES + "/" + templateId + "/archive").then().statusCode(200);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void invalidAndUnknownRequestsAnswerDocumentedErrors() {
        json().body(Map.of("title", " ", "points", 1, "latePoints", 0))
                .post(TEMPLATES)
                .then()
                .statusCode(400);
        json().post(TASKS + "/" + UUID.randomUUID() + "/complete")
                .then()
                .statusCode(404)
                .body("code", is("not_found"));
        json().get(TEMPLATES + "/" + UUID.randomUUID() + "/recurrence").then().statusCode(404);
    }

    @Test
    @TestSecurity(user = MEMBER_SUBJECT, roles = "member")
    void aMemberCannotCreateTemplates() {
        json().body(Map.of("title", "Bins", "points", 1, "latePoints", 0))
                .post(TEMPLATES)
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
    }

    @Test
    @TestSecurity(user = OUTSIDER_SUBJECT, roles = "member")
    void aNonMemberCannotListTasks() {
        json().get(TASKS).then().statusCode(403).body("code", is("forbidden"));
    }

    @Test
    void anonymousCallersAreRejected() {
        given().get(TASKS).then().statusCode(401);
    }

    private static String createTemplate(String title) {
        return json().body(
                        Map.of(
                                "title",
                                title,
                                "emoji",
                                "🗑️",
                                "description",
                                "Take out bins",
                                "points",
                                5,
                                "latePoints",
                                2,
                                "defaultDueOffsetMinutes",
                                60))
                .post(TEMPLATES)
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    private static String createOpenTask(String templateId) {
        return json().body(
                        Map.of(
                                "templateId", templateId,
                                "assigneeId", MEMBER_USER,
                                "dueAt", Instant.now().plusSeconds(7200).toString()))
                .post(TASKS)
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    private static RequestSpecification json() {
        return given().contentType(ContentType.JSON);
    }
}
