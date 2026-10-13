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
import com.betterhome.scoring.service.ScoreboardService.Scoreboard;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class ScoringPhase3Test {

    private static final UUID HOUSEHOLD = UUID.fromString("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID ADMIN_USER = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");

    @Inject LedgerService ledgerService;

    @Inject ScoreboardService scoreboardService;

    @Inject InMemoryMembershipGateway membershipGateway;

    @Inject CurrentIdentityAssociation identityAssociation;

    @BeforeEach
    @Transactional
    void seedMembers() {
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, false, 2)));
        PointTransaction.delete("householdId = ?1", HOUSEHOLD);
    }

    @Test
    void awardReverseScoreboardAndNeverNegative() {
        UUID task1 = UUID.randomUUID();
        UUID task2 = UUID.randomUUID();

        asUser(
                MEMBER_SUBJECT,
                () ->
                        ledgerService.award(
                                HOUSEHOLD, MEMBER_USER, task1, 5, PointReason.task_completed));
        asUser(
                MEMBER_SUBJECT,
                () ->
                        ledgerService.award(
                                HOUSEHOLD, MEMBER_USER, task2, 2, PointReason.task_completed_late));
        asUser(
                ADMIN_SUBJECT,
                () ->
                        ledgerService.award(
                                HOUSEHOLD,
                                ADMIN_USER,
                                UUID.randomUUID(),
                                3,
                                PointReason.task_completed));

        Scoreboard board =
                asUser(
                        MEMBER_SUBJECT,
                        () -> scoreboardService.scoreboard(HOUSEHOLD, ScorePeriod.all, null));
        assertEquals(10, board.totalPoints());
        assertEquals(MEMBER_USER, board.podium().get(0).userId());
        assertEquals(7, board.podium().get(0).points());
        assertTrue(board.entries().get(0).effortShare() > 0.6);

        asUser(
                ADMIN_SUBJECT,
                () ->
                        ledgerService.reverse(
                                HOUSEHOLD,
                                task1,
                                MEMBER_USER,
                                ADMIN_USER,
                                5,
                                "Wrong person",
                                ReversionResultingStatus.open));

        int memberSum = PointTransaction.sumForUser(HOUSEHOLD, MEMBER_USER);
        assertEquals(2, memberSum);

        assertThrows(
                ScoringException.Forbidden.class,
                () ->
                        ledgerService.reverse(
                                HOUSEHOLD,
                                task2,
                                MEMBER_USER,
                                MEMBER_USER,
                                2,
                                "Nope",
                                ReversionResultingStatus.reverted));

        asUser(
                ADMIN_SUBJECT,
                () ->
                        assertThrows(
                                ScoringException.Conflict.class,
                                () -> ledgerService.adjust(HOUSEHOLD, MEMBER_USER, -100)));

        asUser(ADMIN_SUBJECT, () -> ledgerService.adjust(HOUSEHOLD, MEMBER_USER, -1));
        assertEquals(1, PointTransaction.sumForUser(HOUSEHOLD, MEMBER_USER));
        assertTrue(PointTransaction.sumForUser(HOUSEHOLD, MEMBER_USER) >= 0);
    }

    @Test
    void closeMonthBuildsHallOfWinners() {
        asUser(
                MEMBER_SUBJECT,
                () ->
                        ledgerService.award(
                                HOUSEHOLD,
                                MEMBER_USER,
                                UUID.randomUUID(),
                                10,
                                PointReason.task_completed));
        asUser(
                ADMIN_SUBJECT,
                () ->
                        scoreboardService.closeMonth(
                                HOUSEHOLD,
                                java.time.YearMonth.now(java.time.ZoneOffset.UTC).toString()));

        var winners = asUser(MEMBER_SUBJECT, () -> scoreboardService.winners(HOUSEHOLD));
        assertEquals(1, winners.size());
        assertEquals(MEMBER_USER, winners.get(0).winnerUserId());
        assertEquals(10, winners.get(0).winnerPoints());
    }

    private <T> T asUser(UUID authSubject, Supplier<T> action) {
        SecurityIdentity previous = identityAssociation.getIdentity();
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder()
                        .setPrincipal(() -> authSubject.toString())
                        .addRole("member")
                        .build());
        try {
            return action.get();
        } finally {
            if (previous != null) {
                identityAssociation.setIdentity(previous);
            } else {
                identityAssociation.setIdentity(
                        QuarkusSecurityIdentity.builder().setAnonymous(true).build());
            }
        }
    }
}
