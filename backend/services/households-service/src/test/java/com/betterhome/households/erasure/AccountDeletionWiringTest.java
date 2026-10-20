package com.betterhome.households.erasure;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.households.SecurityTestSupport;
import com.betterhome.households.TestClock;
import com.betterhome.households.domain.AccountDeletion;
import com.betterhome.households.domain.AccountDeletionStep;
import com.betterhome.households.erasure.FakeDeletionTargetsServer.Call;
import com.betterhome.households.service.AccountDeletionService;
import com.betterhome.households.service.CurrentUserService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Account deletion through the real REST clients, the service-account token and the Keycloak
 * boundary, against a local HTTP server. The recording stand-ins used by the other tests are not
 * selected here.
 */
@QuarkusTest
@TestProfile(AccountDeletionWiringTest.RealClients.class)
@QuarkusTestResource(value = FakeDeletionTargetsServer.class, restrictToAnnotatedClass = true)
class AccountDeletionWiringTest {

    /** Keeps only the test clock as an alternative: the real clients and Keycloak admin stay. */
    public static class RealClients implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "quarkus.arc.selected-alternatives", "com.betterhome.households.TestClock");
        }
    }

    @Inject SecurityTestSupport security;
    @Inject CurrentUserService currentUserService;
    @Inject AccountDeletionService accountDeletionService;
    @Inject AccountDeletionProcessor processor;
    @Inject TestClock clock;

    private UUID subject;
    private UUID userId;

    @BeforeEach
    void setUp() {
        clock.reset();
        FakeDeletionTargetsServer.reset();
        subject = UUID.randomUUID();
        userId =
                security.asUser(
                                subject,
                                () ->
                                        currentUserService.sync(
                                                "wiring-" + subject + "@example.com",
                                                "W",
                                                "T",
                                                "en",
                                                "UTC"))
                        .id;
    }

    @AfterEach
    void restoreClock() {
        clock.reset();
    }

    private List<Call> calls() {
        return FakeDeletionTargetsServer.CALLS;
    }

    private Set<String> confirmed() {
        return QuarkusTransaction.requiringNew()
                .call(() -> AccountDeletionStep.doneTargets(userId));
    }

    private boolean completed() {
        return QuarkusTransaction.requiringNew()
                .call(() -> AccountDeletion.<AccountDeletion>findById(userId).completedAt != null);
    }

    @Test
    void everyTargetIsCalledWithTheServiceTokenOnTheDocumentedRoute() {
        security.asUser(subject, () -> accountDeletionService.deleteMyAccount());

        for (String service : List.of("tasks", "scoring", "lists", "notifications")) {
            assertTrue(
                    calls().contains(
                                    new Call(
                                            service,
                                            "POST",
                                            "/v1/internal/users/" + userId + "/anonymize",
                                            "Bearer " + FakeDeletionTargetsServer.TOKEN)),
                    service);
        }
        assertTrue(
                calls().contains(
                                new Call(
                                        "kc",
                                        "DELETE",
                                        "/users/" + subject,
                                        "Bearer " + FakeDeletionTargetsServer.TOKEN)));
        assertEquals(5, calls().size());
        assertTrue(completed());
    }

    @Test
    void keycloakAnsweringNotFoundMeansTheLoginIsAlreadyGone() {
        FakeDeletionTargetsServer.STATUS.put("kc", 404);

        security.asUser(subject, () -> accountDeletionService.deleteMyAccount());

        assertTrue(completed());
        assertTrue(confirmed().contains("identity"));
    }

    @Test
    void aServiceAnsweringAnErrorIsRetriedAfterTheBackoff() {
        FakeDeletionTargetsServer.STATUS.put("scoring", 500);

        security.asUser(subject, () -> accountDeletionService.deleteMyAccount());

        assertFalse(completed());
        assertEquals(Set.of("tasks", "lists", "notifications", "identity"), confirmed());

        FakeDeletionTargetsServer.STATUS.put("scoring", 200);
        clock.advance(Duration.ofMinutes(1));
        assertTrue(processor.process(userId));
        assertEquals(2, calls().stream().filter(call -> call.target().equals("scoring")).count());
        assertEquals(1, calls().stream().filter(call -> call.target().equals("tasks")).count());
    }

    @Test
    void aDroppedConnectionToKeycloakIsRetried() {
        FakeDeletionTargetsServer.STATUS.put("kc", -1);

        security.asUser(subject, () -> accountDeletionService.deleteMyAccount());

        assertFalse(completed());
        assertEquals(Set.of("tasks", "scoring", "lists", "notifications"), confirmed());

        FakeDeletionTargetsServer.STATUS.put("kc", 204);
        clock.advance(Duration.ofMinutes(1));
        assertTrue(processor.process(userId));
    }

    @Test
    void aKeycloakRefusalIsRetried() {
        FakeDeletionTargetsServer.STATUS.put("kc", 403);

        security.asUser(subject, () -> accountDeletionService.deleteMyAccount());

        assertFalse(completed());
        assertEquals(Set.of("tasks", "scoring", "lists", "notifications"), confirmed());
    }
}
