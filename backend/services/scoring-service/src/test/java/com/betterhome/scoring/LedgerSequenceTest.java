package com.betterhome.scoring;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.scoring.domain.PointReason;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ReversionResultingStatus;
import com.betterhome.scoring.domain.ScorePeriod;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.membership.InMemoryMembershipGateway;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import com.betterhome.scoring.service.LedgerService;
import com.betterhome.scoring.service.ScoreboardService;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Random sequences of awards, reversals and adjustments through the real service and PostgreSQL:
 * what is accepted, the ledger sums and the scores shown must match an independent model after
 * every step. The model uses plain arithmetic, not the rules the service uses.
 */
@QuarkusTest
class LedgerSequenceTest {

    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("f1111111-1111-1111-1111-111111111111");
    private static final UUID ADMIN_USER = UUID.fromString("faaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final List<UUID> USERS =
            List.of(
                    ADMIN_USER,
                    UUID.fromString("fbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
                    UUID.fromString("fccccccc-cccc-cccc-cccc-cccccccccccc"));

    @Inject LedgerService ledgerService;
    @Inject ScoreboardService scoreboardService;
    @Inject InMemoryMembershipGateway membershipGateway;
    @Inject CurrentIdentityAssociation identityAssociation;

    private UUID household;

    @BeforeEach
    void setUp() {
        household = UUID.randomUUID();
        membershipGateway.clear();
        membershipGateway.replaceHouseholdMembers(
                household,
                List.of(
                        new MemberView(USERS.get(0), ADMIN_SUBJECT, true, false, 1),
                        new MemberView(USERS.get(1), UUID.randomUUID(), false, false, 2),
                        new MemberView(USERS.get(2), UUID.randomUUID(), false, false, 3)));
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder()
                        .setPrincipal(() -> ADMIN_SUBJECT.toString())
                        .addRole("member")
                        .addRole("admin")
                        .build());
    }

    @Test
    void randomSequencesKeepTheDatabaseLedgerSoundWhateverTheOrder() {
        for (long seed : new long[] {11, 29, 2026, 77_001}) {
            runSequence(new Random(seed), 80, "seed " + seed);
        }
    }

    private void runSequence(Random random, int steps, String label) {
        Map<UUID, Long> sumByUser = new HashMap<>();
        Map<UUID, UUID> ownerOfTask = new HashMap<>();
        Map<UUID, Long> awarded = new HashMap<>();
        Map<UUID, Long> reversed = new HashMap<>();
        List<UUID> tasks =
                java.util.stream.IntStream.range(0, 6).mapToObj(i -> UUID.randomUUID()).toList();
        household = UUID.randomUUID();
        membershipGateway.replaceHouseholdMembers(
                household,
                List.of(
                        new MemberView(USERS.get(0), ADMIN_SUBJECT, true, false, 1),
                        new MemberView(USERS.get(1), UUID.randomUUID(), false, false, 2),
                        new MemberView(USERS.get(2), UUID.randomUUID(), false, false, 3)));

        for (int step = 0; step < steps; step++) {
            String where = label + " step " + step;
            UUID task = tasks.get(random.nextInt(tasks.size()));
            UUID user = USERS.get(random.nextInt(USERS.size()));
            switch (random.nextInt(3)) {
                case 0 -> {
                    if (ownerOfTask.containsKey(task)) {
                        continue;
                    }
                    int points = 1 + random.nextInt(20);
                    ledgerService.award(
                            household, user, task, 1, points, PointReason.task_completed);
                    ownerOfTask.put(task, user);
                    awarded.put(task, (long) points);
                    sumByUser.merge(user, (long) points, Long::sum);
                }
                case 1 -> {
                    UUID owner = ownerOfTask.getOrDefault(task, user);
                    int points = random.nextInt(28) - 2;
                    long remaining =
                            awarded.getOrDefault(task, 0L) - reversed.getOrDefault(task, 0L);
                    boolean allowed = points > 0 && remaining >= points;
                    if (allowed) {
                        ledgerService.reverse(
                                household,
                                task,
                                owner,
                                ADMIN_USER,
                                points,
                                "Not clean",
                                ReversionResultingStatus.open);
                        reversed.merge(task, (long) points, Long::sum);
                        sumByUser.merge(owner, (long) -points, Long::sum);
                    } else {
                        assertThrows(
                                ScoringException.class,
                                () ->
                                        ledgerService.reverse(
                                                household,
                                                task,
                                                owner,
                                                ADMIN_USER,
                                                points,
                                                "Not clean",
                                                ReversionResultingStatus.open),
                                where + ": a reversal of " + points + " must be refused");
                    }
                }
                default -> {
                    int delta = random.nextInt(41) - 20;
                    long current = sumByUser.getOrDefault(user, 0L);
                    boolean allowed = delta != 0 && current + delta >= 0;
                    if (allowed) {
                        ledgerService.adjust(household, user, delta);
                        sumByUser.merge(user, (long) delta, Long::sum);
                    } else {
                        assertThrows(
                                ScoringException.class,
                                () -> ledgerService.adjust(household, user, delta),
                                where + ": an adjustment of " + delta + " must be refused");
                    }
                }
            }
            assertBooksMatch(where, sumByUser, awarded, reversed);
        }
    }

    private void assertBooksMatch(
            String where,
            Map<UUID, Long> sumByUser,
            Map<UUID, Long> awarded,
            Map<UUID, Long> reversed) {
        for (UUID user : USERS) {
            assertEquals(
                    sumByUser.getOrDefault(user, 0L),
                    (long) PointTransaction.sumForUser(household, user),
                    where + ": ledger sum of " + user);
        }
        for (Map.Entry<UUID, Long> entry : awarded.entrySet()) {
            assertEquals(
                    entry.getValue() - reversed.getOrDefault(entry.getKey(), 0L),
                    (long) PointTransaction.sumAwardedForTask(household, entry.getKey()),
                    where + ": awarded minus reversed for the task");
        }
        var board = scoreboardService.scoreboard(household, ScorePeriod.all, null);
        for (var entry : board.entries()) {
            assertTrue(entry.points() >= 0, where + ": a score shown below zero");
            assertEquals(
                    Math.max(0L, sumByUser.getOrDefault(entry.userId(), 0L)),
                    (long) entry.points(),
                    where + ": the score shown");
        }
    }

    @Test
    void anAdjustmentFollowedByAReversalCanTakeTheLedgerBelowZeroButTheShownScoreStaysAtZero() {
        // Documents today's behaviour (T-0087 asks whether it is wanted): reverse checks the task,
        // not the member's total, so adjust -5 then reverse a 5-point task leaves the sum at -5.
        UUID user = USERS.get(1);
        UUID task = UUID.randomUUID();
        ledgerService.award(household, user, task, 1, 5, PointReason.task_completed);
        ledgerService.adjust(household, user, -5);
        ledgerService.reverse(
                household,
                task,
                user,
                ADMIN_USER,
                5,
                "Wrong person",
                ReversionResultingStatus.open);

        assertEquals(-5, PointTransaction.sumForUser(household, user));
        var board = scoreboardService.scoreboard(household, ScorePeriod.all, null);
        assertEquals(
                0,
                board.entries().stream()
                        .filter(e -> e.userId().equals(user))
                        .findFirst()
                        .orElseThrow()
                        .points());
    }
}
