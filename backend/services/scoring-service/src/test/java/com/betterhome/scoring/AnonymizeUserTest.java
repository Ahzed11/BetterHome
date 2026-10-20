package com.betterhome.scoring;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.openapi.ContractValidation;
import com.betterhome.scoring.domain.MonthlyRecap;
import com.betterhome.scoring.domain.MonthlyRecapCelebration;
import com.betterhome.scoring.domain.PointReason;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ReversionResultingStatus;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.domain.TaskReversion;
import com.betterhome.scoring.service.AnonymizationService;
import com.betterhome.scoring.service.AnonymizationService.Result;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Account deletion in scoring-service: the service itself, then the internal endpoint. */
@QuarkusTest
class AnonymizeUserTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");
    private static final UUID ANONYMOUS = new UUID(0L, 0L);

    @Inject AnonymizationService service;
    @Inject EntityManager entityManager;

    private UUID leaver;
    private UUID other;
    private UUID household;
    private UUID awardOfLeaver;
    private UUID reversalOfLeaver;
    private UUID awardOfOther;
    private UUID reversionByLeaver;
    private UUID recapWonByLeaver;
    private UUID recapWonByOther;

    @BeforeEach
    void seed() {
        leaver = UUID.randomUUID();
        other = UUID.randomUUID();
        household = UUID.randomUUID();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            UUID task = UUID.randomUUID();
                            awardOfLeaver = row(leaver, task, 5, PointReason.task_completed, null);
                            awardOfOther =
                                    row(
                                            other,
                                            UUID.randomUUID(),
                                            3,
                                            PointReason.task_completed,
                                            null);
                            TaskReversion reversion = new TaskReversion();
                            reversion.id = UUID.randomUUID();
                            reversion.householdId = household;
                            reversion.taskId = task;
                            reversion.adminUserId = leaver;
                            reversion.reason = "Not done properly";
                            reversion.pointsReversed = 5;
                            reversion.resultingStatus = ReversionResultingStatus.reverted;
                            reversion.createdAt = T0;
                            reversion.persist();
                            reversionByLeaver = reversion.id;
                            reversalOfLeaver =
                                    row(leaver, task, -5, PointReason.reversal, reversion.id);
                            recapWonByLeaver = recap("2026-01", leaver).id;
                            recapWonByOther = recap("2026-02", other).id;
                            celebration(recapWonByLeaver, leaver);
                            celebration(recapWonByLeaver, other);
                        });
    }

    private UUID row(UUID user, UUID task, int points, PointReason reason, UUID reversion) {
        PointTransaction tx = new PointTransaction();
        tx.id = UUID.randomUUID();
        tx.householdId = household;
        tx.userId = user;
        tx.taskId = task;
        tx.reversionId = reversion;
        tx.points = points;
        tx.reason = reason;
        tx.createdAt = T0;
        tx.persist();
        return tx.id;
    }

    private MonthlyRecap recap(String month, UUID winner) {
        MonthlyRecap recap = new MonthlyRecap();
        recap.id = UUID.randomUUID();
        recap.householdId = household;
        recap.yearMonth = month;
        recap.winnerUserId = winner;
        recap.winnerPoints = 5;
        recap.totalPoints = 8;
        recap.createdAt = T0;
        recap.persist();
        return recap;
    }

    private static void celebration(UUID recap, UUID user) {
        MonthlyRecapCelebration seen = new MonthlyRecapCelebration();
        seen.recapId = recap;
        seen.userId = user;
        seen.seenAt = T0;
        seen.persist();
    }

    private <T> T reload(Class<T> type, UUID id) {
        return QuarkusTransaction.requiringNew().call(() -> entityManager.find(type, id));
    }

    private int householdTotal() {
        return QuarkusTransaction.requiringNew()
                .call(
                        () ->
                                entityManager
                                        .createQuery(
                                                "select coalesce(sum(p.points), 0) from"
                                                        + " PointTransaction p where p.householdId"
                                                        + " = ?1",
                                                Long.class)
                                        .setParameter(1, household)
                                        .getSingleResult()
                                        .intValue());
    }

    @Test
    void everyColumnHoldingTheUserIsReplacedAndTheLedgerStaysTheSame() {
        int totalBefore = householdTotal();

        Result result = service.anonymize(leaver);

        assertEquals(new Result(2, 1, 1, 1L), result);
        PointTransaction award = reload(PointTransaction.class, awardOfLeaver);
        assertEquals(ANONYMOUS, award.userId);
        assertEquals(5, award.points);
        assertEquals(T0, award.createdAt);
        assertEquals(ANONYMOUS, reload(PointTransaction.class, reversalOfLeaver).userId);
        assertEquals(other, reload(PointTransaction.class, awardOfOther).userId);
        assertEquals(ANONYMOUS, reload(TaskReversion.class, reversionByLeaver).adminUserId);
        assertEquals(ANONYMOUS, reload(MonthlyRecap.class, recapWonByLeaver).winnerUserId);
        assertEquals(other, reload(MonthlyRecap.class, recapWonByOther).winnerUserId);
        assertEquals(totalBefore, householdTotal());
        assertFalse(MonthlyRecapCelebration.hasSeen(recapWonByLeaver, leaver));
        assertTrue(MonthlyRecapCelebration.hasSeen(recapWonByLeaver, other));
    }

    @Test
    void doingItAgainChangesNothing() {
        service.anonymize(leaver);

        assertEquals(new Result(0, 0, 0, 0L), service.anonymize(leaver));
    }

    @Test
    void aUserWithNoHistoryHereChangesNothing() {
        assertEquals(new Result(0, 0, 0, 0L), service.anonymize(UUID.randomUUID()));
        assertEquals(leaver, reload(PointTransaction.class, awardOfLeaver).userId);
    }

    @Test
    void theAnonymousIdItselfIsRefused() {
        assertThrows(ScoringException.BadRequest.class, () -> service.anonymize(ANONYMOUS));
    }

    private String url(UUID user) {
        return "/v1/internal/users/" + user + "/anonymize";
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void theServiceRoleAnonymizesOverHttp() {
        given().filter(ContractValidation.validRequests("scoring"))
                .post(url(leaver))
                .then()
                .statusCode(200)
                .body("ledgerRows", is(2))
                .body("reversions", is(1))
                .body("recapsWon", is(1))
                .body("celebrationsForgotten", is(1));

        assertEquals(ANONYMOUS, reload(PointTransaction.class, awardOfLeaver).userId);
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void repeatingOverHttpAnswersOkWithZeroes() {
        given().post(url(leaver)).then().statusCode(200);

        given().filter(ContractValidation.validRequests("scoring"))
                .post(url(leaver))
                .then()
                .statusCode(200)
                .body("ledgerRows", is(0))
                .body("reversions", is(0))
                .body("recapsWon", is(0))
                .body("celebrationsForgotten", is(0));
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void theAnonymousIdIsRefusedOverHttp() {
        given().post(url(ANONYMOUS)).then().statusCode(400);
    }

    @Test
    @TestSecurity(
            user = "someone",
            roles = {"admin", "member"})
    void householdUsersAreRefusedAndNothingChanges() {
        given().post(url(leaver)).then().statusCode(403);

        assertEquals(leaver, reload(PointTransaction.class, awardOfLeaver).userId);
    }

    @Test
    void anonymousCallersAreRefused() {
        given().post(url(leaver)).then().statusCode(401);
    }
}
