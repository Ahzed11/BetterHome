package com.betterhome.households;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.hamcrest.CoreMatchers.nullValue;
import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.common.oidc.RealOidcTestResource;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import java.util.Map;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The profile, household and membership endpoints over HTTP with real tokens. The contract filter
 * installed for every test of this service checks each answer, so these calls prove the real
 * answers (including the error bodies) equal the documented ones.
 */
@QuarkusTest
@QuarkusTestResource(value = RealOidcTestResource.class, restrictToAnnotatedClass = true)
class MembershipHttpTest {

    @Inject @RestClient RecordingTasksClient tasksClient;

    private String admin;
    private String member;
    private String outsider;
    private String memberId;
    private String adminId;
    private String householdId;

    @BeforeEach
    void seed() {
        tasksClient.reset();
        admin = RealOidcTestResource.token(UUID.randomUUID(), "ada");
        member = RealOidcTestResource.token(UUID.randomUUID(), "mo");
        outsider = RealOidcTestResource.token(UUID.randomUUID(), "out");
        String suffix = UUID.randomUUID().toString();
        adminId = sync(admin, "ada-" + suffix + "@example.com");
        memberId = sync(member, "mo-" + suffix + "@example.com");
        sync(outsider, "out-" + suffix + "@example.com");
        householdId =
                as(admin)
                        .body(Map.of("name", "Flatshare", "timezone", "Europe/Paris"))
                        .post("/v1/households")
                        .then()
                        .statusCode(201)
                        .extract()
                        .path("id");
        String token =
                as(admin)
                        .body(Map.of("email", "mo-" + suffix + "@example.com", "role", "member"))
                        .post(base() + "/invitations")
                        .then()
                        .statusCode(201)
                        .extract()
                        .path("token");
        plain(member).post("/v1/invitations/" + token + "/accept").then().statusCode(200);
    }

    @Test
    void getMyProfileReturnsTheSyncedProfile() {
        plain(admin).get("/v1/me").then().statusCode(200).body("id", is(adminId));
    }

    @Test
    void getMyProfileOfAnUnknownUserIsNotFound() {
        String stranger = RealOidcTestResource.token(UUID.randomUUID(), "new");
        plain(stranger).get("/v1/me").then().statusCode(404).body("code", is("not_found"));
    }

    @Test
    void invalidProfileSyncAnswersBadRequest() {
        as(admin)
                .body(Map.of("email", "not-an-email"))
                .put("/v1/me")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
    }

    @Test
    void profileEndpointsRejectAnonymousCallers() {
        given().get("/v1/me").then().statusCode(401);
        given().contentType(ContentType.JSON).body("{}").put("/v1/me").then().statusCode(401);
    }

    @Test
    void anAdminUpdatesAndDeletesTheHousehold() {
        as(admin)
                .body(
                        Map.of(
                                "name", "Renamed",
                                "reminderDaysBefore", 2,
                                "reminderTime", "09:30:00"))
                .patch("/v1/households/" + householdId)
                .then()
                .statusCode(200)
                .body("name", is("Renamed"))
                .body("reminderDaysBefore", is(2));

        plain(admin).delete("/v1/households/" + householdId).then().statusCode(204);
        plain(admin)
                .get("/v1/households/" + householdId)
                .then()
                .statusCode(404)
                .body("code", is("not_found"));
    }

    @Test
    void householdUpdateAndDeleteErrors() {
        as(admin)
                .body(Map.of("name", " "))
                .patch("/v1/households/" + householdId)
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
        as(admin)
                .body(Map.of("reminderDaysBefore", -1))
                .patch("/v1/households/" + householdId)
                .then()
                .statusCode(400);
        as(member)
                .body(Map.of("name", "Mine now"))
                .patch("/v1/households/" + householdId)
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
        plain(member).delete("/v1/households/" + householdId).then().statusCode(403);
        plain(outsider).delete("/v1/households/" + householdId).then().statusCode(403);
        plain(admin)
                .delete("/v1/households/" + UUID.randomUUID())
                .then()
                .statusCode(404)
                .body("code", is("not_found"));
        given().delete("/v1/households/" + householdId).then().statusCode(401);
    }

    @Test
    void anAdminChangesRolesButNeverDemotesTheLastAdmin() {
        as(admin)
                .body(Map.of("role", "admin"))
                .patch(base() + "/members/" + memberId + "/role")
                .then()
                .statusCode(200)
                .body("role", is("admin"));
        as(admin)
                .body(Map.of("role", "member"))
                .patch(base() + "/members/" + adminId + "/role")
                .then()
                .statusCode(200)
                .body("role", is("member"));
        as(member)
                .body(Map.of("role", "member"))
                .patch(base() + "/members/" + memberId + "/role")
                .then()
                .statusCode(409)
                .body("code", is("conflict"));
    }

    @Test
    void roleChangeErrors() {
        as(admin)
                .body(Map.of())
                .patch(base() + "/members/" + memberId + "/role")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
        as(member)
                .body(Map.of("role", "admin"))
                .patch(base() + "/members/" + memberId + "/role")
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
        as(outsider)
                .body(Map.of("role", "admin"))
                .patch(base() + "/members/" + memberId + "/role")
                .then()
                .statusCode(403);
        as(admin)
                .body(Map.of("role", "admin"))
                .patch(base() + "/members/" + UUID.randomUUID() + "/role")
                .then()
                .statusCode(403);
        as(admin)
                .body(Map.of("role", "admin"))
                .patch("/v1/households/" + UUID.randomUUID() + "/members/" + memberId + "/role")
                .then()
                .statusCode(404);
        given().contentType(ContentType.JSON)
                .body(Map.of("role", "admin"))
                .patch(base() + "/members/" + memberId + "/role")
                .then()
                .statusCode(401);
    }

    @Test
    void anAdminMarksAMemberAwayAndClearsIt() {
        as(admin)
                .body(Map.of("awayUntil", "2999-01-01T00:00:00Z"))
                .post(base() + "/members/" + memberId + "/away")
                .then()
                .statusCode(200)
                .body("awayFrom", notNullValue())
                .body("awayUntil", is("2999-01-01T00:00:00Z"));
        assertEquals(1, tasksClient.calls().size());

        plain(admin)
                .delete(base() + "/members/" + memberId + "/away")
                .then()
                .statusCode(200)
                .body("awayFrom", nullValue())
                .body("awayUntil", nullValue());

        as(admin)
                .body(
                        Map.of(
                                "awayFrom", "2999-01-01T00:00:00Z",
                                "awayUntil", "2999-02-01T00:00:00Z"))
                .post(base() + "/members/" + memberId + "/away")
                .then()
                .statusCode(200)
                .body("awayFrom", is("2999-01-01T00:00:00Z"));
        assertEquals(1, tasksClient.calls().size(), "a future away period dismisses nothing yet");
    }

    @Test
    void awayErrors() {
        as(admin)
                .body(
                        Map.of(
                                "awayFrom", "2999-02-01T00:00:00Z",
                                "awayUntil", "2999-01-01T00:00:00Z"))
                .post(base() + "/members/" + memberId + "/away")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
        as(member)
                .body(Map.of())
                .post(base() + "/members/" + adminId + "/away")
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
        plain(member).delete(base() + "/members/" + adminId + "/away").then().statusCode(403);
        as(outsider)
                .body(Map.of())
                .post(base() + "/members/" + memberId + "/away")
                .then()
                .statusCode(403);
        plain(outsider).delete(base() + "/members/" + memberId + "/away").then().statusCode(403);
        as(admin)
                .body(Map.of())
                .post("/v1/households/" + UUID.randomUUID() + "/members/" + memberId + "/away")
                .then()
                .statusCode(404);
        given().contentType(ContentType.JSON)
                .body(Map.of())
                .post(base() + "/members/" + memberId + "/away")
                .then()
                .statusCode(401);
        given().delete(base() + "/members/" + memberId + "/away").then().statusCode(401);
    }

    @Test
    void anUnreachableTasksServiceFailsTheAwayChangeAndSavesNothing() {
        tasksClient.failWith(new ProcessingException("tasks-service is down"));

        as(admin)
                .body(Map.of())
                .post(base() + "/members/" + memberId + "/away")
                .then()
                .statusCode(503)
                .body("code", is("service_unavailable"));

        plain(admin)
                .get(base() + "/members")
                .then()
                .statusCode(200)
                .body("find { it.userId == '" + memberId + "' }.awayFrom", nullValue());
    }

    @Test
    void membersListAndLeaveErrors() {
        plain(member).get(base() + "/members").then().statusCode(200).body("$", hasSize(2));
        plain(outsider).get(base() + "/members").then().statusCode(403);
        given().get(base() + "/members").then().statusCode(401);

        plain(admin)
                .post(base() + "/members/me/leave")
                .then()
                .statusCode(409)
                .body("code", is("conflict"));
        plain(outsider).post(base() + "/members/me/leave").then().statusCode(403);
        plain(admin)
                .post("/v1/households/" + UUID.randomUUID() + "/members/me/leave")
                .then()
                .statusCode(404);
        given().post(base() + "/members/me/leave").then().statusCode(401);

        plain(member).post(base() + "/members/me/leave").then().statusCode(204);
        plain(member).post(base() + "/members/me/leave").then().statusCode(403);
        plain(admin).get(base() + "/members").then().statusCode(200).body("$", hasSize(1));
    }

    private String base() {
        return "/v1/households/" + householdId;
    }

    private static String sync(String token, String email) {
        return as(token)
                .body(
                        Map.of(
                                "email", email,
                                "givenName", "G",
                                "familyName", "F",
                                "language", "en",
                                "timezone", "UTC"))
                .put("/v1/me")
                .then()
                .statusCode(200)
                .extract()
                .path("id");
    }

    private static RequestSpecification plain(String token) {
        return given().auth().oauth2(token);
    }

    private static RequestSpecification as(String token) {
        return plain(token).contentType(ContentType.JSON);
    }
}
