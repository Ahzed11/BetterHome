package com.betterhome.households;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.hasSize;

import com.betterhome.households.domain.MembershipRole;
import com.betterhome.households.service.CurrentUserService;
import com.betterhome.households.service.HouseholdService;
import com.betterhome.households.service.InvitationService;
import com.betterhome.households.service.MembershipService;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class InternalHouseholdResourceTest {

    private static final UUID ADMIN_SUBJECT = UUID.fromString("66666666-6666-6666-6666-666666666666");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("77777777-7777-7777-7777-777777777777");
    private static final UUID OTHER_SUBJECT = UUID.fromString("88888888-8888-8888-8888-888888888888");

    @Inject SecurityTestSupport security;
    @Inject CurrentUserService currentUserService;
    @Inject HouseholdService householdService;
    @Inject InvitationService invitationService;
    @Inject MembershipService membershipService;

    private UUID householdId;
    private UUID memberUserId;
    private UUID otherHouseholdId;

    @BeforeEach
    void setUp() {
        security.asUser(
                ADMIN_SUBJECT,
                () -> currentUserService.sync("int-admin@example.com", "Ada", "A", "en", "UTC"));
        security.asUser(
                MEMBER_SUBJECT,
                () -> currentUserService.sync("int-member@example.com", "Mo", "M", "en", "UTC"));
        security.asUser(
                OTHER_SUBJECT,
                () -> currentUserService.sync("int-other@example.com", "Ot", "O", "en", "UTC"));
        householdId =
                security.asUser(
                        ADMIN_SUBJECT,
                        () -> householdService.create("Internal", "Europe/Paris").id);
        otherHouseholdId =
                security.asUser(OTHER_SUBJECT, () -> householdService.create("Elsewhere", "UTC").id);
        var invitation =
                security.asUser(
                        ADMIN_SUBJECT,
                        () ->
                                invitationService.create(
                                        householdId,
                                        "int-member@example.com",
                                        MembershipRole.member));
        memberUserId =
                security.asUser(MEMBER_SUBJECT, () -> invitationService.accept(invitation.token))
                        .userId;
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void serviceAccountListsOnlyThatHouseholdsMembersWithAuthSubject() {
        given().when()
                .get("/v1/internal/households/" + householdId + "/members")
                .then()
                .statusCode(200)
                .body("$", hasSize(2))
                .body("[0].role", is("admin"))
                .body("[0].authSubject", is(ADMIN_SUBJECT.toString()))
                .body("[0].away", is(false))
                .body("[1].role", is("member"))
                .body("[1].authSubject", is(MEMBER_SUBJECT.toString()))
                .body("[1].userId", is(memberUserId.toString()));
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void awayMembersAreFlagged() {
        security.asUser(
                ADMIN_SUBJECT,
                () -> membershipService.setAway(householdId, memberUserId, null, null));

        given().when()
                .get("/v1/internal/households/" + householdId + "/members")
                .then()
                .statusCode(200)
                .body("[1].away", is(true));
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void serviceAccountReadsSettings() {
        given().when()
                .get("/v1/internal/households/" + householdId + "/settings")
                .then()
                .statusCode(200)
                .body("timezone", is("Europe/Paris"))
                .body("reminderDaysBefore", is(0));
    }

    @Test
    @TestSecurity(user = "tasks-service", roles = "service")
    void unknownHouseholdIsNotFound() {
        given().when()
                .get("/v1/internal/households/" + UUID.randomUUID() + "/members")
                .then()
                .statusCode(404);
        given().when()
                .get("/v1/internal/households/" + UUID.randomUUID() + "/settings")
                .then()
                .statusCode(404);
    }

    @Test
    @TestSecurity(user = "77777777-7777-7777-7777-777777777777", roles = "member")
    void householdMembersCannotUseInternalEndpoints() {
        given().when().get("/v1/internal/households/" + householdId + "/members").then().statusCode(403);
        given().when().get("/v1/internal/households/" + householdId + "/settings").then().statusCode(403);
    }

    @Test
    @TestSecurity(user = "66666666-6666-6666-6666-666666666666", roles = {"member", "admin"})
    void householdAdminsCannotUseInternalEndpointsEither() {
        given().when().get("/v1/internal/households/" + otherHouseholdId + "/members").then().statusCode(403);
    }

    @Test
    void anonymousIsRejected() {
        given().when().get("/v1/internal/households/" + householdId + "/members").then().statusCode(401);
    }
}
