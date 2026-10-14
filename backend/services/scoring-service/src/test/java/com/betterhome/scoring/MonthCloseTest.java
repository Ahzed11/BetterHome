package com.betterhome.scoring;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.scoring.domain.MonthCloseCursor;
import com.betterhome.scoring.domain.MonthlyRecap;
import com.betterhome.scoring.domain.PointReason;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.membership.InMemoryMembershipGateway;
import com.betterhome.scoring.service.MonthCloser;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The scheduled close: each month is closed once, at the household's local boundary. */
@QuarkusTest
class MonthCloseTest {

    private static final UUID ALICE = UUID.fromString("ea000000-0000-0000-0000-000000000001");
    private static final UUID BOB = UUID.fromString("eb000000-0000-0000-0000-000000000002");
    private static final ZoneId BRUSSELS = ZoneId.of("Europe/Brussels");
    private static final ZoneId NEW_YORK = ZoneId.of("America/New_York");

    @Inject MonthCloser monthCloser;
    @Inject InMemoryMembershipGateway membershipGateway;
    @Inject TestClock clock;

    private UUID household;

    @BeforeEach
    void setUp() {
        membershipGateway.clear();
        household = UUID.randomUUID();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            MonthCloseCursor.deleteAll();
                            MonthlyRecap.deleteAll();
                            PointTransaction.deleteAll();
                        });
    }

    @AfterEach
    void tearDown() {
        clock.useSystemTime();
        membershipGateway.clear();
    }

    private void earned(UUID home, UUID user, int points, String when) {
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            PointTransaction row = new PointTransaction();
                            row.id = UUID.randomUUID();
                            row.householdId = home;
                            row.userId = user;
                            row.taskId = points > 0 ? UUID.randomUUID() : null;
                            row.completionNo = points > 0 ? 1 : null;
                            row.points = points;
                            row.reason =
                                    points > 0
                                            ? PointReason.task_completed
                                            : PointReason.manual_adjust;
                            row.createdAt = Instant.parse(when);
                            row.persist();
                        });
    }

    private void earned(UUID user, int points, String when) {
        earned(household, user, points, when);
    }

    private int closeAt(String now) {
        clock.fixAt(Instant.parse(now));
        return monthCloser.closeDue(100);
    }

    private List<MonthlyRecap> recaps(UUID home) {
        return QuarkusTransaction.requiringNew()
                .call(
                        () ->
                                MonthlyRecap.<MonthlyRecap>list(
                                        "householdId = ?1 order by yearMonth", home));
    }

    private MonthCloseCursor cursor(UUID home) {
        return QuarkusTransaction.requiringNew()
                .call(() -> MonthCloseCursor.<MonthCloseCursor>findById(home));
    }

    @Test
    void aMonthIsClosedOnlyOnceItsLocalEndHasPassed() {
        membershipGateway.putZone(household, BRUSSELS);
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        earned(BOB, 3, "2026-03-21T10:00:00Z");

        assertEquals(0, closeAt("2026-03-31T21:59:59Z"), "one second before local midnight");
        assertTrue(recaps(household).isEmpty());

        assertEquals(1, closeAt("2026-03-31T22:00:00Z"), "local midnight, 1 April in Brussels");

        MonthlyRecap march = recaps(household).getFirst();
        assertEquals("2026-03", march.yearMonth);
        assertEquals(ALICE, march.winnerUserId);
        assertEquals(5, march.winnerPoints);
        assertEquals(8, march.totalPoints);
        assertEquals("2026-04", cursor(household).nextMonth);
        assertEquals(Instant.parse("2026-04-30T22:00:00Z"), cursor(household).nextCloseAt);
    }

    @Test
    void aUtcHouseholdClosesAtUtcMidnight() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");

        assertEquals(0, closeAt("2026-03-31T22:00:00Z"));
        assertTrue(recaps(household).isEmpty());
        assertEquals(1, closeAt("2026-04-01T00:00:00Z"));
        assertEquals(1, recaps(household).size());
    }

    @Test
    void springForwardMovesTheBoundaryToFourUtcInNewYork() {
        membershipGateway.putZone(household, NEW_YORK);
        earned(ALICE, 5, "2026-03-20T10:00:00Z");

        assertEquals(0, closeAt("2026-04-01T03:59:59Z"));
        assertEquals(1, closeAt("2026-04-01T04:00:00Z"));
    }

    @Test
    void fallingBackKeepsOctoberOpenUntilFourUtcOnFirstNovember() {
        membershipGateway.putZone(household, NEW_YORK);
        earned(ALICE, 5, "2026-10-20T10:00:00Z");

        assertEquals(0, closeAt("2026-11-01T03:59:59Z"));
        assertEquals(1, closeAt("2026-11-01T04:00:00Z"));
        assertEquals("2026-10", recaps(household).getFirst().yearMonth);
    }

    @Test
    void monthsMissedWhileTheServiceWasDownAreCaughtUpAndEmptyOnesGetNoRecap() {
        membershipGateway.putZone(household, BRUSSELS);
        earned(ALICE, 4, "2026-01-10T10:00:00Z");
        earned(BOB, 6, "2026-03-10T10:00:00Z");

        assertEquals(1, closeAt("2026-05-02T10:00:00Z"));

        assertEquals(
                List.of("2026-01", "2026-03"),
                recaps(household).stream().map(r -> r.yearMonth).toList(),
                "February had no points");
        assertEquals(BOB, recaps(household).get(1).winnerUserId);
        assertEquals("2026-05", cursor(household).nextMonth);
    }

    @Test
    void closingAgainChangesNothing() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        closeAt("2026-04-02T10:00:00Z");
        MonthlyRecap first = recaps(household).getFirst();

        assertEquals(0, closeAt("2026-04-02T11:00:00Z"));

        assertEquals(1, recaps(household).size());
        assertEquals(first.id, recaps(household).getFirst().id);
    }

    @Test
    void aTieGoesToTheLowestUserIdLikeTheScoreboardRanks() {
        earned(BOB, 5, "2026-03-20T10:00:00Z");
        earned(ALICE, 5, "2026-03-21T10:00:00Z");

        closeAt("2026-04-02T10:00:00Z");

        assertEquals(ALICE, recaps(household).getFirst().winnerUserId);
        assertEquals(10, recaps(household).getFirst().totalPoints);
    }

    @Test
    void aMemberBelowZeroNeitherWinsNorCounts() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        earned(BOB, 2, "2026-03-21T10:00:00Z");
        earned(BOB, -6, "2026-03-22T10:00:00Z");

        closeAt("2026-04-02T10:00:00Z");

        MonthlyRecap march = recaps(household).getFirst();
        assertEquals(ALICE, march.winnerUserId);
        assertEquals(5, march.totalPoints, "scores never go negative and a negative adds nothing");
    }

    @Test
    void aMonthWhoseNetPointsAreZeroGetsNoRecap() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        earned(ALICE, -5, "2026-03-21T10:00:00Z");

        assertEquals(1, closeAt("2026-04-02T10:00:00Z"));

        assertTrue(recaps(household).isEmpty());
    }

    @Test
    void aRecapAnAdminClosedByHandIsLeftAlone() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            MonthlyRecap manual = new MonthlyRecap();
                            manual.id = UUID.randomUUID();
                            manual.householdId = household;
                            manual.yearMonth = "2026-03";
                            manual.winnerUserId = BOB;
                            manual.winnerPoints = 99;
                            manual.totalPoints = 99;
                            manual.createdAt = Instant.parse("2026-03-31T12:00:00Z");
                            manual.persist();
                        });

        closeAt("2026-04-02T10:00:00Z");

        assertEquals(BOB, recaps(household).getFirst().winnerUserId);
        assertEquals(99, recaps(household).getFirst().winnerPoints);
    }

    @Test
    void aTimezoneThatMovedTheBoundaryLaterPostponesTheClose() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        closeAt("2026-03-25T10:00:00Z"); // registered as a UTC household: due 1 April 00:00Z
        membershipGateway.putZone(household, ZoneId.of("America/Los_Angeles"));

        assertEquals(1, closeAt("2026-04-01T01:00:00Z"), "the stored time passed: it looks again");

        assertTrue(recaps(household).isEmpty(), "but March has not ended in Los Angeles yet");
        assertEquals(Instant.parse("2026-04-01T07:00:00Z"), cursor(household).nextCloseAt);
        assertEquals("2026-03", cursor(household).nextMonth);

        assertEquals(1, closeAt("2026-04-01T07:00:00Z"));
        assertEquals("2026-03", recaps(household).getFirst().yearMonth);
    }

    @Test
    void whenHouseholdsServiceIsDownTheHouseholdWaitsAndNothingIsHalfDone() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        closeAt("2026-03-25T10:00:00Z"); // registered
        membershipGateway.setUnavailable(true);

        assertEquals(1, closeAt("2026-04-02T10:00:00Z"));

        assertTrue(recaps(household).isEmpty());
        assertEquals("2026-03", cursor(household).nextMonth, "still on the same month");
        assertEquals(Instant.parse("2026-04-02T10:01:00Z"), cursor(household).nextCloseAt);
        assertEquals(0, closeAt("2026-04-02T10:00:30Z"), "not before the retry time");

        membershipGateway.setUnavailable(false);
        assertEquals(1, closeAt("2026-04-02T10:01:00Z"));
        assertEquals(1, recaps(household).size());
    }

    @Test
    void aHouseholdIsRegisteredOnlyOnceItHasLedgerRows() {
        closeAt("2026-04-02T10:00:00Z");
        assertNull(cursor(household));

        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        closeAt("2026-03-25T10:00:00Z");

        MonthCloseCursor registered = cursor(household);
        assertNotNull(registered);
        assertEquals("2026-03", registered.nextMonth, "starts at the month of its first row");
    }

    @Test
    void whenHouseholdsServiceIsDownAtFirstSightTheHouseholdIsPickedUpLater() {
        earned(ALICE, 5, "2026-03-20T10:00:00Z");
        membershipGateway.setUnavailable(true);

        closeAt("2026-04-02T10:00:00Z");
        assertNull(cursor(household));

        membershipGateway.setUnavailable(false);
        assertEquals(1, closeAt("2026-04-02T10:05:00Z"));
        assertEquals(1, recaps(household).size());
    }

    @Test
    void theLimitBoundsHowManyHouseholdsOneRunCloses() {
        for (int i = 0; i < 3; i++) {
            earned(UUID.randomUUID(), ALICE, 5, "2026-03-20T10:00:00Z");
        }
        clock.fixAt(Instant.parse("2026-04-02T10:00:00Z"));

        assertEquals(2, monthCloser.closeDue(2));
        assertEquals(1, monthCloser.closeDue(2));
    }

    @Test
    void severalReplicasCloseEveryHouseholdExactlyOnce() throws Exception {
        List<UUID> households = new ArrayList<>();
        for (int i = 0; i < 24; i++) {
            UUID home = UUID.randomUUID();
            households.add(home);
            earned(home, ALICE, 5, "2026-03-20T10:00:00Z");
        }
        membershipGateway.setLatencyMillis(20);
        clock.fixAt(Instant.parse("2026-04-02T10:00:00Z"));

        ExecutorService pool = Executors.newFixedThreadPool(4);
        int claimed = 0;
        try {
            List<Future<Integer>> runs = new ArrayList<>();
            for (int i = 0; i < 4; i++) {
                runs.add(pool.submit(() -> monthCloser.closeDue(100)));
            }
            for (Future<Integer> run : runs) {
                claimed += run.get(120, TimeUnit.SECONDS);
            }
        } finally {
            pool.shutdownNow();
        }

        assertEquals(24, claimed, "every household was taken by exactly one replica");
        Set<UUID> withRecap = new HashSet<>();
        for (UUID home : households) {
            assertEquals(1, recaps(home).size(), "one recap for " + home);
            withRecap.add(home);
        }
        assertEquals(24, withRecap.size());
    }
}
