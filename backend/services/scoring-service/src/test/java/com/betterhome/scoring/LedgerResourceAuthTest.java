package com.betterhome.scoring;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.membership.InMemoryMembershipGateway;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class LedgerResourceAuthTest {

    private static final UUID HOUSEHOLD = UUID.fromString("cccccccc-bbbb-cccc-dddd-eeeeeeeeeeee");
    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("33333333-3333-3333-3333-333333333333");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("44444444-4444-4444-4444-444444444444");
    private static final UUID ADMIN_USER = UUID.fromString("cccccccc-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("dddddddd-bbbb-bbbb-bbbb-bbbbbbbbbbbb");

    @Inject InMemoryMembershipGateway membershipGateway;

    @BeforeEach
    @AfterEach
    @Transactional
    void reset() {
        membershipGateway.clear();
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, false, 2)));
        PointTransaction.delete("householdId = ?1", HOUSEHOLD);
    }

    private Map<String, Object> awardBody(UUID taskId) {
        return Map.of(
                "userId", MEMBER_USER, "taskId", taskId, "points", 4, "reason", "task_completed");
    }

    private Map<String, Object> reverseBody(UUID taskId, UUID adminUserId) {
        return Map.of(
                "taskId",
                taskId,
                "assigneeUserId",
                MEMBER_USER,
                "adminUserId",
                adminUserId,
                "points",
                4,
                "reason",
                "Wrong person",
                "resultingStatus",
                "open");
    }

    private io.restassured.response.ValidatableResponse postAward(UUID taskId) {
        return given().contentType("application/json")
                .body(awardBody(taskId))
                .when()
                .post("/v1/households/" + HOUSEHOLD + "/points/award")
                .then();
    }

    private io.restassured.response.ValidatableResponse postReverse(UUID taskId, UUID adminUserId) {
        return given().contentType("application/json")
                .body(reverseBody(taskId, adminUserId))
                .when()
                .post("/v1/households/" + HOUSEHOLD + "/points/reverse")
                .then();
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void serviceAccountAwardsThenReverses() {
        UUID taskId = UUID.randomUUID();

        postAward(taskId)
                .statusCode(201)
                .body("userId", is(MEMBER_USER.toString()))
                .body("points", is(4))
                .body("reason", is("task_completed"));
        postReverse(taskId, ADMIN_USER)
                .statusCode(201)
                .body("adminUserId", is(ADMIN_USER.toString()))
                .body("pointsReversed", is(4));
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void reversalMustBeOrderedByAnActiveAdmin() {
        UUID taskId = UUID.randomUUID();
        postAward(taskId).statusCode(201);

        postReverse(taskId, MEMBER_USER).statusCode(403);
        postReverse(taskId, UUID.randomUUID()).statusCode(403);
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void reversingMoreThanWasAwardedConflicts() {
        postReverse(UUID.randomUUID(), ADMIN_USER).statusCode(409);
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void aHouseholdsOutageAnswers503AndTheReversalCanBeRetried() {
        UUID taskId = UUID.randomUUID();
        postAward(taskId).statusCode(201);
        membershipGateway.setUnavailable(true);

        postReverse(taskId, ADMIN_USER).statusCode(503).body("code", is("service_unavailable"));

        membershipGateway.setUnavailable(false);
        postReverse(taskId, ADMIN_USER).statusCode(201);
    }

    @Test
    @TestSecurity(
            user = "33333333-3333-3333-3333-333333333333",
            roles = {"member", "admin"})
    void householdAdminsCannotWriteTheLedgerDirectly() {
        postAward(UUID.randomUUID()).statusCode(403);
        postReverse(UUID.randomUUID(), ADMIN_USER).statusCode(403);
    }

    @Test
    @TestSecurity(user = "44444444-4444-4444-4444-444444444444", roles = "member")
    void plainMembersCannotWriteTheLedgerDirectly() {
        postAward(UUID.randomUUID()).statusCode(403);
        postReverse(UUID.randomUUID(), ADMIN_USER).statusCode(403);
    }

    @Test
    void anonymousIsRejected() {
        postAward(UUID.randomUUID()).statusCode(401);
        postReverse(UUID.randomUUID(), ADMIN_USER).statusCode(401);
    }

    @Test
    @TestSecurity(user = "44444444-4444-4444-4444-444444444444", roles = "member")
    void aMembersScoreboardAnswers503WhenHouseholdsIsDown() {
        membershipGateway.setUnavailable(true);

        given().when()
                .get("/v1/households/" + HOUSEHOLD + "/scoreboard")
                .then()
                .statusCode(503)
                .body("code", is("service_unavailable"));
    }
}
