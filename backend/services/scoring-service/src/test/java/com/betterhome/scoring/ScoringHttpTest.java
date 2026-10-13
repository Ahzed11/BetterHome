package com.betterhome.scoring;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.hasSize;

import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.membership.InMemoryMembershipGateway;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The scoring endpoints over HTTP. The contract filter installed for every test of this service
 * checks each answer (status, headers, body, no undocumented field) against the committed OpenAPI
 * document, so these calls prove the real answers equal the documented ones.
 */
@QuarkusTest
class ScoringHttpTest {

    private static final UUID HOUSEHOLD = UUID.fromString("cccccccc-bbbb-cccc-dddd-eeeeeeeeeeee");
    private static final String ADMIN_SUBJECT = "11111111-1111-1111-1111-111111111111";
    private static final String MEMBER_SUBJECT = "22222222-2222-2222-2222-222222222222";
    private static final String OUTSIDER_SUBJECT = "33333333-3333-3333-3333-333333333333";
    private static final UUID ADMIN_USER = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    private static final String POINTS = "/v1/households/" + HOUSEHOLD + "/points";
    private static final String SCOREBOARD = "/v1/households/" + HOUSEHOLD + "/scoreboard";

    @Inject InMemoryMembershipGateway membershipGateway;

    @BeforeEach
    @Transactional
    void seedMembers() {
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, UUID.fromString(ADMIN_SUBJECT), true, false, 1),
                        new MemberView(
                                MEMBER_USER, UUID.fromString(MEMBER_SUBJECT), false, false, 2)));
        PointTransaction.delete("householdId = ?1", HOUSEHOLD);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void adminRunsTheLedgerAndReadsTheScoreboardAndRecap() {
        UUID taskId = UUID.randomUUID();
        json().body(award(taskId, 5)).post(POINTS + "/award").then().statusCode(201);
        json().body(Map.of("userId", MEMBER_USER, "delta", 3))
                .post(POINTS + "/adjust")
                .then()
                .statusCode(201);
        json().body(
                        Map.of(
                                "taskId",
                                taskId,
                                "assigneeUserId",
                                MEMBER_USER,
                                "points",
                                2,
                                "reason",
                                "Wrong person",
                                "resultingStatus",
                                "open"))
                .post(POINTS + "/reverse")
                .then()
                .statusCode(201);

        json().get(SCOREBOARD).then().statusCode(200).body("totalPoints", is(6));
        json().get(SCOREBOARD + "?period=all").then().statusCode(200);
        json().get(SCOREBOARD + "?period=week").then().statusCode(200);
        json().body(Map.of("yearMonth", "2026-01"))
                .post(SCOREBOARD + "/close-month")
                .then()
                .statusCode(200);
        json().get(SCOREBOARD + "/winners").then().statusCode(200).body("$", hasSize(1));
        json().post(SCOREBOARD + "/recaps/2026-01/celebrate").then().statusCode(200);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT, roles = "admin")
    void invalidAndConflictingRequestsAnswerDocumentedErrors() {
        json().body(Map.of("userId", MEMBER_USER, "delta", 0))
                .post(POINTS + "/adjust")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
        json().body(Map.of("userId", MEMBER_USER, "delta", -4))
                .post(POINTS + "/adjust")
                .then()
                .statusCode(409);
        json().get(SCOREBOARD + "?period=month&yearMonth=nope").then().statusCode(400);
        json().body(award(UUID.randomUUID(), 0))
                .post(POINTS + "/award")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
    }

    @Test
    @TestSecurity(user = MEMBER_SUBJECT, roles = "member")
    void aMemberCannotAdjustPoints() {
        json().body(Map.of("userId", MEMBER_USER, "delta", 3))
                .post(POINTS + "/adjust")
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
    }

    @Test
    @TestSecurity(user = OUTSIDER_SUBJECT, roles = "member")
    void aNonMemberCannotReadTheScoreboard() {
        json().get(SCOREBOARD).then().statusCode(403).body("code", is("forbidden"));
    }

    @Test
    void anonymousCallersAreRejected() {
        given().get(SCOREBOARD).then().statusCode(401);
    }

    private static Map<String, Object> award(UUID taskId, int points) {
        return Map.of(
                "userId", MEMBER_USER,
                "taskId", taskId,
                "points", points,
                "reason", "task_completed");
    }

    private static RequestSpecification json() {
        return given().contentType(ContentType.JSON);
    }
}
