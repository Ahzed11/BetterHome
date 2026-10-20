package com.betterhome.households;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import com.betterhome.households.service.CurrentUserService;
import com.betterhome.households.service.HouseholdService;
import com.betterhome.households.service.InvitationService;
import com.betterhome.households.service.MembershipService;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

@QuarkusTest
class HouseholdPhase1Test {

    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID OUTSIDER_SUBJECT =
            UUID.fromString("33333333-3333-3333-3333-333333333333");

    @Inject SecurityTestSupport security;

    @Inject CurrentUserService currentUserService;

    @Inject HouseholdService householdService;

    @Inject MembershipService membershipService;

    @Inject InvitationService invitationService;

    @Test
    @TestSecurity(user = "11111111-1111-1111-1111-111111111111", roles = "member")
    void syncCreateListAndGetHouseholdViaHttp() {
        given().contentType(ContentType.JSON)
                .body(
                        Map.of(
                                "email", "admin@example.com",
                                "givenName", "Ada",
                                "familyName", "Admin",
                                "language", "en",
                                "timezone", "Europe/Paris"))
                .when()
                .put("/v1/me")
                .then()
                .statusCode(200)
                .body("email", is("admin@example.com"))
                .body("authSubject", is(ADMIN_SUBJECT.toString()));

        String householdId =
                given().contentType(ContentType.JSON)
                        .body(Map.of("name", "Flatshare", "timezone", "Europe/Paris"))
                        .when()
                        .post("/v1/households")
                        .then()
                        .statusCode(201)
                        .body("name", is("Flatshare"))
                        .body("reminderDaysBefore", is(0))
                        .body("id", notNullValue())
                        .extract()
                        .path("id");

        given().when()
                .get("/v1/households")
                .then()
                .statusCode(200)
                .body("$", hasSize(greaterThanOrEqualTo(1)));

        given().when()
                .get("/v1/households/" + householdId)
                .then()
                .statusCode(200)
                .body("id", is(householdId));

        given().when()
                .get("/v1/households/" + householdId + "/members")
                .then()
                .statusCode(200)
                .body("$", hasSize(1))
                .body("[0].role", is("admin"))
                .body("[0].givenName", is("Ada"))
                .body("[0].familyName", is("Admin"));
    }

    @Test
    @TestSecurity(user = "11111111-1111-1111-1111-111111111111", roles = "member")
    void invalidHouseholdPayloadAnswersTheDocumentedErrorBody() {
        given().contentType(ContentType.JSON)
                .body(Map.of("name", " ", "timezone", "UTC"))
                .when()
                .post("/v1/households")
                .then()
                .statusCode(400)
                .body("code", is("bad_request"));
    }

    @Test
    void inviteAcceptRoleAwayAndLastAdminGuard() {
        var admin =
                security.asUser(
                        ADMIN_SUBJECT,
                        () ->
                                currentUserService.sync(
                                        "admin2@example.com", "Ada", "Admin", "en", "UTC"));
        var member =
                security.asUser(
                        MEMBER_SUBJECT,
                        () ->
                                currentUserService.sync(
                                        "member@example.com", "Mo", "Member", "fr", "UTC"));
        security.asUser(
                OUTSIDER_SUBJECT,
                () -> currentUserService.sync("out@example.com", "Out", "Sidr", "en", "UTC"));

        var household =
                security.asUser(
                        ADMIN_SUBJECT, () -> householdService.create("House B", "Europe/Berlin"));

        var invitation =
                security.asUser(
                        ADMIN_SUBJECT,
                        () ->
                                invitationService.create(
                                        household.id, "member@example.com", MembershipRole.member));

        security.asUser(
                MEMBER_SUBJECT,
                () -> {
                    Membership joined = invitationService.accept(invitation.token);
                    assertEquals(MembershipRole.member, joined.role);
                    assertEquals(household.id, joined.householdId);
                });

        security.asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.Forbidden.class,
                                () ->
                                        invitationService.create(
                                                household.id,
                                                "other@example.com",
                                                MembershipRole.member)));

        security.asUser(
                OUTSIDER_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.Forbidden.class,
                                () -> householdService.get(household.id)));

        security.asUser(
                ADMIN_SUBJECT,
                () -> {
                    Membership away =
                            membershipService.setAway(
                                    household.id,
                                    member.id,
                                    Instant.parse("2026-01-01T00:00:00Z"),
                                    Instant.parse("2026-01-10T00:00:00Z"));
                    assertTrue(away.isAway(Instant.parse("2026-01-05T00:00:00Z")));
                    Membership cleared = membershipService.clearAway(household.id, member.id);
                    assertEquals(null, cleared.awayFrom);
                });

        security.asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.Forbidden.class,
                                () ->
                                        membershipService.setAway(
                                                household.id, admin.id, null, null)));

        security.asUser(
                ADMIN_SUBJECT,
                () -> membershipService.changeRole(household.id, member.id, MembershipRole.admin));

        security.asUser(ADMIN_SUBJECT, () -> membershipService.leave(household.id));

        security.asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.Conflict.class,
                                () -> membershipService.leave(household.id)));
    }

    @Test
    void lastAdminCannotLeaveWithoutHandover() {
        security.asUser(
                ADMIN_SUBJECT,
                () -> currentUserService.sync("solo@example.com", "Solo", "Admin", "en", "UTC"));
        var household =
                security.asUser(ADMIN_SUBJECT, () -> householdService.create("Solo House", "UTC"));
        security.asUser(
                ADMIN_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.Conflict.class,
                                () -> membershipService.leave(household.id)));
        security.asUser(ADMIN_SUBJECT, () -> householdService.delete(household.id));
        security.asUser(
                ADMIN_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.NotFound.class,
                                () -> householdService.get(household.id)));
    }
}
