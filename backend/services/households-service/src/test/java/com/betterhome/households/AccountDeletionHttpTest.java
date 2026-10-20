package com.betterhome.households;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.containsString;
import static org.hamcrest.CoreMatchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.common.oidc.RealOidcTestResource;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code DELETE /v1/me} over HTTP with real tokens. The contract filter installed for every test of
 * this service checks each answer, error bodies included, against the committed OpenAPI document.
 */
@QuarkusTest
@QuarkusTestResource(value = RealOidcTestResource.class, restrictToAnnotatedClass = true)
class AccountDeletionHttpTest {

    @Inject RecordingAnonymizeClients services;
    @Inject InMemoryIdentityAdmin identity;

    private UUID leaverSubject;
    private UUID otherSubject;
    private String leaver;
    private String other;
    private String leaverId;
    private String otherEmail;

    @BeforeEach
    void seed() {
        services.reset();
        identity.reset();
        leaverSubject = UUID.randomUUID();
        otherSubject = UUID.randomUUID();
        leaver = RealOidcTestResource.token(leaverSubject, "lea");
        other = RealOidcTestResource.token(otherSubject, "oto");
        leaverId = sync(leaver, "lea-" + leaverSubject + "@example.com");
        otherEmail = "oto-" + otherSubject + "@example.com";
        sync(other, otherEmail);
    }

    @Test
    void deletingTheAccountAnswersAcceptedAndTheProfileIsGone() {
        as(leaver).delete("/v1/me").then().statusCode(202);

        plain(leaver).get("/v1/me").then().statusCode(404).body("code", is("not_found"));
        for (RecordingAnonymizeClient client : services.all()) {
            assertEquals(List.of(UUID.fromString(leaverId)), client.calls());
        }
        assertEquals(List.of(leaverSubject), identity.deleted());
    }

    @Test
    void theProfileCannotBeRecreatedWithTheSameToken() {
        as(leaver).delete("/v1/me").then().statusCode(202);

        as(leaver)
                .body(Map.of("email", "again@example.com"))
                .put("/v1/me")
                .then()
                .statusCode(403)
                .body("code", is("forbidden"));
    }

    @Test
    void deletingTwiceStaysAcceptedAndTellsTheTargetsOnce() {
        as(leaver).delete("/v1/me").then().statusCode(202);
        as(leaver).delete("/v1/me").then().statusCode(202);

        for (RecordingAnonymizeClient client : services.all()) {
            assertEquals(1, client.calls().size());
        }
    }

    @Test
    void theOnlyAdminOfAHouseholdWithOthersIsToldToHandOverFirst() {
        String household = createHousehold(leaver);
        invite(household, leaver, other, otherEmail);

        as(leaver)
                .delete("/v1/me")
                .then()
                .statusCode(409)
                .body("code", is("conflict"))
                .body("message", containsString("only admin"));

        plain(leaver).get("/v1/me").then().statusCode(200).body("id", is(leaverId));
        plain(leaver).get("/v1/households/" + household).then().statusCode(200);
        for (RecordingAnonymizeClient client : services.all()) {
            assertEquals(0, client.calls().size());
        }

        as(leaver)
                .body(Map.of("role", "admin"))
                .patch("/v1/households/" + household + "/members/" + userId(other) + "/role")
                .then()
                .statusCode(200);
        as(leaver).delete("/v1/me").then().statusCode(202);
        plain(other).get("/v1/households/" + household).then().statusCode(200);
    }

    @Test
    void aTokenWithoutAProfileIsNotFound() {
        String stranger = RealOidcTestResource.token(UUID.randomUUID(), "new");

        as(stranger).delete("/v1/me").then().statusCode(404).body("code", is("not_found"));
    }

    @Test
    void anonymousCallersAreRefused() {
        given().delete("/v1/me").then().statusCode(401);
    }

    private String userId(String token) {
        return plain(token).get("/v1/me").then().statusCode(200).extract().path("id");
    }

    private String createHousehold(String token) {
        return as(token)
                .body(Map.of("name", "Flatshare", "timezone", "Europe/Paris"))
                .post("/v1/households")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    private void invite(String household, String admin, String joiner, String email) {
        String token =
                as(admin)
                        .body(Map.of("email", email, "role", "member"))
                        .post("/v1/households/" + household + "/invitations")
                        .then()
                        .statusCode(201)
                        .extract()
                        .path("token");
        plain(joiner).post("/v1/invitations/" + token + "/accept").then().statusCode(200);
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
