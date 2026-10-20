package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.common.openapi.ContractValidation;
import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationPreference;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.service.AnonymizationService;
import com.betterhome.notifications.service.AnonymizationService.Result;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Account deletion in notifications-service: the service itself, then the internal endpoint. */
@QuarkusTest
class AnonymizeUserTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");

    @Inject AnonymizationService service;

    private UUID leaver;
    private UUID other;

    @BeforeEach
    void seed() {
        leaver = UUID.randomUUID();
        other = UUID.randomUUID();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            notification(leaver, Channel.in_app);
                            notification(leaver, Channel.push);
                            notification(other, Channel.in_app);
                            preference(leaver);
                            preference(other);
                        });
    }

    private static void notification(UUID user, Channel channel) {
        Notification n = new Notification();
        n.id = UUID.randomUUID();
        n.householdId = UUID.randomUUID();
        n.userId = user;
        n.type = NotificationType.task_assigned;
        n.channel = channel;
        n.title = "New task";
        n.body = "Dishes";
        n.payload = Map.of("taskTitle", "Dishes");
        n.idempotencyKey = UUID.randomUUID().toString();
        n.createdAt = T0;
        n.persist();
    }

    private static void preference(UUID user) {
        NotificationPreference p = new NotificationPreference();
        p.id = UUID.randomUUID();
        p.userId = user;
        p.type = NotificationType.task_assigned;
        p.channel = Channel.push;
        p.enabled = false;
        p.updatedAt = T0;
        p.persist();
    }

    private static long notificationsOf(UUID user) {
        return QuarkusTransaction.requiringNew().call(() -> Notification.count("userId", user));
    }

    private static long preferencesOf(UUID user) {
        return QuarkusTransaction.requiringNew()
                .call(() -> NotificationPreference.count("userId", user));
    }

    @Test
    void everythingOfTheUserIsDeletedAndNobodyElsesIsTouched() {
        assertEquals(new Result(2L, 1L), service.anonymize(leaver));

        assertEquals(0, notificationsOf(leaver));
        assertEquals(0, preferencesOf(leaver));
        assertEquals(1, notificationsOf(other));
        assertEquals(1, preferencesOf(other));
    }

    @Test
    void doingItAgainChangesNothing() {
        service.anonymize(leaver);

        assertEquals(new Result(0L, 0L), service.anonymize(leaver));
    }

    @Test
    void aUserWithNothingHereChangesNothing() {
        assertEquals(new Result(0L, 0L), service.anonymize(UUID.randomUUID()));
        assertEquals(2, notificationsOf(leaver));
    }

    private String url(UUID user) {
        return "/v1/internal/users/" + user + "/anonymize";
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void theServiceRoleAnonymizesOverHttp() {
        given().filter(ContractValidation.validRequests("notifications"))
                .post(url(leaver))
                .then()
                .statusCode(200)
                .body("notificationsDeleted", is(2))
                .body("preferencesDeleted", is(1));

        assertEquals(0, notificationsOf(leaver));
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void repeatingOverHttpAnswersOkWithZeroes() {
        given().post(url(leaver)).then().statusCode(200);

        given().filter(ContractValidation.validRequests("notifications"))
                .post(url(leaver))
                .then()
                .statusCode(200)
                .body("notificationsDeleted", is(0))
                .body("preferencesDeleted", is(0));
    }

    @Test
    @TestSecurity(
            user = "someone",
            roles = {"admin", "member"})
    void householdUsersAreRefusedAndNothingChanges() {
        given().post(url(leaver)).then().statusCode(403);

        assertEquals(2, notificationsOf(leaver));
    }

    @Test
    void anonymousCallersAreRefused() {
        given().post(url(leaver)).then().statusCode(401);
    }
}
