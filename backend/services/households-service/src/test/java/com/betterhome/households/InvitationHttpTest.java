package com.betterhome.households;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.notNullValue;

import com.betterhome.common.oidc.RealOidcTestResource;
import com.betterhome.common.openapi.ContractValidation;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Invitations over HTTP with real tokens, as the routing of a running server sees them. */
@QuarkusTest
@QuarkusTestResource(value = RealOidcTestResource.class, restrictToAnnotatedClass = true)
class InvitationHttpTest {

    @Test
    void adminInvitesAndTheInviteeJoinsThroughTheApi() {
        String admin = RealOidcTestResource.token(UUID.randomUUID(), "ada");
        String invitee = RealOidcTestResource.token(UUID.randomUUID(), "mo");
        sync(admin, "ada-http@example.com");
        sync(invitee, "mo-http@example.com");
        String householdId =
                validAs(admin)
                        .body(Map.of("name", "Flatshare", "timezone", "Europe/Paris"))
                        .post("/v1/households")
                        .then()
                        .statusCode(201)
                        .extract()
                        .path("id");

        String token =
                validAs(admin)
                        .body(Map.of("email", "mo-http@example.com", "role", "member"))
                        .post("/v1/households/" + householdId + "/invitations")
                        .then()
                        .statusCode(201)
                        .body("token", notNullValue())
                        .extract()
                        .path("token");
        validAs(admin)
                .get("/v1/households/" + householdId + "/invitations")
                .then()
                .statusCode(200)
                .body("$", hasSize(1))
                .body("[0].email", is("mo-http@example.com"));

        withoutContentType(invitee)
                .post("/v1/invitations/" + token + "/accept")
                .then()
                .statusCode(200)
                .body("role", is("member"));
        validAs(admin)
                .get("/v1/households/" + householdId + "/members")
                .then()
                .statusCode(200)
                .body("$", hasSize(2));
        withoutContentType(invitee)
                .post("/v1/households/" + householdId + "/members/me/leave")
                .then()
                .statusCode(204);
    }

    @Test
    void aMemberCannotInviteAndAnOutsiderCannotListInvitations() {
        String admin = RealOidcTestResource.token(UUID.randomUUID(), "ada");
        String outsider = RealOidcTestResource.token(UUID.randomUUID(), "out");
        sync(admin, "ada-http2@example.com");
        sync(outsider, "out-http2@example.com");
        String householdId =
                as(admin)
                        .body(Map.of("name", "Other", "timezone", "UTC"))
                        .post("/v1/households")
                        .then()
                        .statusCode(201)
                        .extract()
                        .path("id");

        as(outsider)
                .body(Map.of("email", "x@example.com", "role", "member"))
                .post("/v1/households/" + householdId + "/invitations")
                .then()
                .statusCode(403);
        as(outsider).get("/v1/households/" + householdId + "/invitations").then().statusCode(403);
        given().post("/v1/invitations/nope/accept").then().statusCode(401);
    }

    private static void sync(String token, String email) {
        validAs(token)
                .body(
                        Map.of(
                                "email", email,
                                "givenName", "G",
                                "familyName", "F",
                                "language", "en",
                                "timezone", "UTC"))
                .put("/v1/me")
                .then()
                .statusCode(200);
    }

    private static RequestSpecification withoutContentType(String token) {
        return given().auth().oauth2(token);
    }

    /** Authenticated JSON request the test means to be valid: checked against the contract. */
    private static RequestSpecification validAs(String token) {
        return as(token).filter(ContractValidation.validRequests("households"));
    }

    private static RequestSpecification as(String token) {
        return given().auth().oauth2(token).contentType(ContentType.JSON);
    }
}
