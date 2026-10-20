package com.betterhome.tasks;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.hasSize;

import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.HouseholdSettings;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import io.quarkus.narayana.jta.QuarkusTransaction;
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
        QuarkusTransaction.requiringNew().run(() -> Task.delete("householdId", HOUSEHOLD));
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
    void actionsWithoutABodyAcceptARequestWithoutContentType() {
        String templateId = createTemplate("Dishes");
        String completeId = createOpenTask(templateId);
        String reassignId = createOpenTask(templateId);
        String dismissId = createOpenTask(templateId);

        given().post(TASKS + "/" + completeId + "/complete").then().statusCode(200);
        given().post(TASKS + "/" + reassignId + "/reassign").then().statusCode(200);
        given().post(TASKS + "/" + reassignId + "/dismiss").then().statusCode(200);
        given().post(TASKS + "/" + dismissId + "/dismiss").then().statusCode(200);
        given().post(TASKS + "/dismiss-away/" + MEMBER_USER).then().statusCode(200);
        given().post(TASKS + "/reassign-away/" + MEMBER_USER).then().statusCode(200);
        given().post(TEMPLATES + "/" + templateId + "/archive").then().statusCode(200);
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
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void dismissAwayDismissesTheOpenTasksOfTheMemberAndCountsThem() {
        String templateId = createTemplate("Floors");
        createOpenTask(templateId);
        createOpenTask(templateId);

        json().post(TASKS + "/dismiss-away/" + MEMBER_USER)
                .then()
                .statusCode(200)
                .body("dismissed", is(2));
        json().post(TASKS + "/dismiss-away/" + MEMBER_USER)
                .then()
                .statusCode(200)
                .body("dismissed", is(0));
        json().get(TASKS + "?status=dismissed")
                .then()
                .statusCode(200)
                .body("$", hasSize(2))
                .body("[0].dismissalReason", is("assignee_away"));
        json().get(TASKS + "?status=open").then().statusCode(200).body("$", hasSize(0));
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void reassignAwayHandsOpenTasksToTheNextMemberOrConflictsWhenNobodyIsEligible() {
        String templateId = createTemplate("Windows");
        createOpenTask(templateId);

        json().post(TASKS + "/reassign-away/" + MEMBER_USER)
                .then()
                .statusCode(200)
                .body("reassigned", is(1));
        json().get(TASKS + "?status=open")
                .then()
                .statusCode(200)
                .body("[0].assigneeId", is(ADMIN_USER.toString()));

        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, UUID.fromString(ADMIN_SUBJECT), true, true, 1),
                        new MemberView(
                                MEMBER_USER, UUID.fromString(MEMBER_SUBJECT), false, true, 2)));
        json().post(TASKS + "/reassign-away/" + ADMIN_USER)
                .then()
                .statusCode(409)
                .body("code", is("conflict"));
    }

    @Test
    @TestSecurity(user = MEMBER_SUBJECT, roles = "member")
    void aMemberCannotDismissOrReassignAwayTasks() {
        json().post(TASKS + "/dismiss-away/" + MEMBER_USER)
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
        json().post(TASKS + "/reassign-away/" + MEMBER_USER)
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
    }

    @Test
    @TestSecurity(user = OUTSIDER_SUBJECT, roles = "member")
    void aNonMemberCannotDismissOrReassignAwayTasks() {
        json().post(TASKS + "/dismiss-away/" + MEMBER_USER).then().statusCode(403);
        json().post(TASKS + "/reassign-away/" + MEMBER_USER).then().statusCode(403);
    }

    @Test
    void anonymousCallersCannotDismissOrReassignAwayTasks() {
        given().post(TASKS + "/dismiss-away/" + MEMBER_USER).then().statusCode(401);
        given().post(TASKS + "/reassign-away/" + MEMBER_USER).then().statusCode(401);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void tasksInTheWrongStateAnswerConflict() {
        String templateId = createTemplate("Laundry");
        String doneId = createOpenTask(templateId);
        json().post(TASKS + "/" + doneId + "/complete").then().statusCode(200);

        json().post(TASKS + "/" + doneId + "/complete")
                .then()
                .statusCode(409)
                .body("code", is("conflict"));
        json().post(TASKS + "/" + doneId + "/dismiss").then().statusCode(409);
        json().post(TASKS + "/" + doneId + "/reassign").then().statusCode(409);

        String openId = createOpenTask(templateId);
        json().body(Map.of("reason", "Too early"))
                .post(TASKS + "/" + openId + "/revert")
                .then()
                .statusCode(409);
        json().body(Map.of("reason", " "))
                .post(TASKS + "/" + doneId + "/revert")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void unknownTemplatesAndTasksAnswerNotFound() {
        UUID missing = UUID.randomUUID();
        json().body(Map.of("templateId", missing))
                .post(TASKS)
                .then()
                .statusCode(404)
                .body("code", is("not_found"));
        json().body(Map.of("templateId", missing)).post(TASKS + "/manual").then().statusCode(404);
        json().post(TASKS + "/" + missing + "/dismiss").then().statusCode(404);
        json().post(TASKS + "/" + missing + "/reassign").then().statusCode(404);
        json().body(Map.of("reason", "Because"))
                .post(TASKS + "/" + missing + "/revert")
                .then()
                .statusCode(404);
        json().body(Map.of("points", 3)).patch(TEMPLATES + "/" + missing).then().statusCode(404);
        json().post(TEMPLATES + "/" + missing + "/archive").then().statusCode(404);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void invalidBodiesAnswerBadRequest() {
        String templateId = createTemplate("Plants");
        json().body(Map.of("assigneeId", MEMBER_USER)).post(TASKS).then().statusCode(400);
        json().body(Map.of()).post(TASKS + "/manual").then().statusCode(400);
        json().body(Map.of("points", -1))
                .patch(TEMPLATES + "/" + templateId)
                .then()
                .statusCode(400);
        json().body(Map.of("rrule", "NOT A RULE", "assignmentMode", "round_robin"))
                .put(TEMPLATES + "/" + templateId + "/recurrence")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
    }

    @Test
    @TestSecurity(user = MEMBER_SUBJECT, roles = "member")
    void aMemberCannotManageTemplatesRecurrencesOrOthersTasks() {
        UUID missing = UUID.randomUUID();
        json().body(Map.of("points", 3))
                .patch(TEMPLATES + "/" + missing)
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
        json().post(TEMPLATES + "/" + missing + "/archive").then().statusCode(403);
        json().body(Map.of("rrule", "FREQ=DAILY", "assignmentMode", "round_robin"))
                .put(TEMPLATES + "/" + missing + "/recurrence")
                .then()
                .statusCode(403);
        json().body(Map.of("templateId", missing)).post(TASKS).then().statusCode(403);
    }

    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void anInvalidStatusFilterIsRejected() {
        json().get(TASKS + "?status=nonsense").then().statusCode(400);
    }

    @Test
    @TestSecurity(user = OUTSIDER_SUBJECT, roles = "member")
    void aNonMemberIsForbiddenEverywhereElse() {
        UUID missing = UUID.randomUUID();
        json().get(TEMPLATES).then().statusCode(403);
        json().get(TEMPLATES + "/" + missing + "/recurrence").then().statusCode(403);
        json().post(TASKS + "/" + missing + "/complete").then().statusCode(403);
        json().body(Map.of("templateId", missing)).post(TASKS + "/manual").then().statusCode(403);
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
