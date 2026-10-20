package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.betterhome.notifications.domain.PushTarget;
import com.betterhome.notifications.service.PushTargetService;
import com.betterhome.notifications.support.InMemoryUsersGateway;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Registering, reading and removing the Gotify token (ADR 0027), and who may do it. */
@QuarkusTest
class PushTargetApiTest {

    private static final String ALICE_SUBJECT = "a1a1a1a1-0000-0000-0000-00000000000a";
    private static final String BOB_SUBJECT = "a1a1a1a1-0000-0000-0000-00000000000b";
    private static final String CAROL_SUBJECT = "a1a1a1a1-0000-0000-0000-00000000000c";
    private static final UUID ALICE = UUID.fromString("a2a2a2a2-0000-0000-0000-00000000000a");
    private static final UUID BOB = UUID.fromString("a2a2a2a2-0000-0000-0000-00000000000b");
    private static final String TOKEN = "AbCdEf0123456789";

    @Inject InMemoryUsersGateway users;
    @Inject PushTargetService targets;
    @Inject EntityManager entityManager;

    @BeforeEach
    @AfterEach
    void reset() {
        QuarkusTransaction.requiringNew().run(() -> PushTarget.deleteAll());
        users.clear();
        users.add(UUID.fromString(ALICE_SUBJECT), ALICE, "en");
        users.add(UUID.fromString(BOB_SUBJECT), BOB, "fr");
    }

    private static ValidatableResponse put(String token) {
        return given().contentType("application/json")
                .body(Map.of("token", token))
                .when()
                .put("/v1/push-target")
                .then();
    }

    private static ValidatableResponse get() {
        return given().when().get("/v1/push-target").then();
    }

    private static ValidatableResponse delete() {
        return given().when().delete("/v1/push-target").then();
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void registeringStoresTheTokenAndNeverEchoesIt() {
        String body =
                put(TOKEN)
                        .statusCode(200)
                        .body("registeredAt", notNullValue())
                        .extract()
                        .asString();

        assertFalse(body.contains(TOKEN));
        assertEquals(TOKEN, targets.tokenOf(ALICE).orElseThrow());
        String read = get().statusCode(200).extract().asString();
        assertFalse(read.contains(TOKEN));
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void registeringAgainReplacesTheTokenAndKeepsTheOriginalDate() {
        String first = put(TOKEN).statusCode(200).extract().path("registeredAt");

        String second = put("Another-token_2").statusCode(200).extract().path("registeredAt");

        assertEquals(first, second);
        assertEquals("Another-token_2", targets.tokenOf(ALICE).orElseThrow());
        assertEquals(1L, PushTarget.count());
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void withoutATargetTheAnswerIsNotFoundAndRemovingIsStillFine() {
        get().statusCode(404).body("code", is("not_found"));
        delete().statusCode(204);
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void removingForgetsTheToken() {
        put(TOKEN).statusCode(200);

        delete().statusCode(204);

        get().statusCode(404);
        assertEquals(0L, PushTarget.count());
    }

    @Test
    @TestSecurity(user = ALICE_SUBJECT, roles = "member")
    void aTokenThatCouldBreakAHeaderOrIsTooLongIsRejected() {
        put("").statusCode(400);
        put("   ").statusCode(400);
        put("abc def").statusCode(400);
        put("abc\r\nX-Evil: 1").statusCode(400);
        put("a".repeat(129)).statusCode(400);
        given().contentType("application/json")
                .body("{}")
                .when()
                .put("/v1/push-target")
                .then()
                .statusCode(400);
        assertEquals(0L, PushTarget.count());
    }

    @Test
    @TestSecurity(user = BOB_SUBJECT, roles = "member")
    void anotherUserNeitherSeesNorChangesAlicesTarget() {
        targets.register(ALICE, TOKEN);

        get().statusCode(404);
        delete().statusCode(204);
        put("Bobs-token").statusCode(200);

        assertEquals(TOKEN, targets.tokenOf(ALICE).orElseThrow());
        assertEquals("Bobs-token", targets.tokenOf(BOB).orElseThrow());
    }

    @Test
    @TestSecurity(user = CAROL_SUBJECT, roles = "member")
    void aUserWithoutAProfileIsForbidden() {
        put(TOKEN).statusCode(403);
        get().statusCode(403);
        delete().statusCode(403);
        assertEquals(0L, PushTarget.count());
    }

    @Test
    @TestSecurity(user = "0a0a0a0a-0000-0000-0000-0000000000aa", roles = "service")
    void theServiceAccountHasNoTargetOfItsOwn() {
        put(TOKEN).statusCode(403);
        get().statusCode(403);
        delete().statusCode(403);
    }

    @Test
    void anonymousCallersAreRejected() {
        put(TOKEN).statusCode(401);
        get().statusCode(401);
        delete().statusCode(401);
    }

    @Test
    void theDatabaseRefusesATokenThatIsNotPlainText() {
        assertThrows(
                PersistenceException.class,
                () ->
                        QuarkusTransaction.requiringNew()
                                .run(
                                        () ->
                                                entityManager
                                                        .createNativeQuery(
                                                                "INSERT INTO push_target (user_id, token, created_at,"
                                                                        + " updated_at) VALUES (:id, 'a b', NOW(), NOW())")
                                                        .setParameter("id", UUID.randomUUID())
                                                        .executeUpdate()));
    }

    @Test
    void removingARefusedTokenLeavesANewerRegistrationAlone() {
        targets.register(ALICE, "old-token");
        targets.register(ALICE, "new-token");

        assertFalse(targets.removeRefused(ALICE, "old-token"));
        assertEquals("new-token", targets.tokenOf(ALICE).orElseThrow());
    }
}
