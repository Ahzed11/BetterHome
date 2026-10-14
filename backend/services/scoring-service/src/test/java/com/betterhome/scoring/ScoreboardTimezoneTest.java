package com.betterhome.scoring;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.betterhome.scoring.domain.PointReason;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ScorePeriod;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.membership.InMemoryMembershipGateway;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import com.betterhome.scoring.service.ScoreboardService;
import com.betterhome.scoring.service.ScoreboardService.Scoreboard;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The scoreboard cuts weeks, months and years at the household's local midnight (spec 3.4). */
@QuarkusTest
class ScoreboardTimezoneTest {

    private static final UUID HOUSEHOLD = UUID.fromString("dddddddd-0000-0000-0000-000000000001");
    private static final UUID SUBJECT = UUID.fromString("d1111111-1111-1111-1111-111111111111");
    private static final UUID USER = UUID.fromString("daaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final ZoneId BRUSSELS = ZoneId.of("Europe/Brussels");

    @Inject ScoreboardService scoreboardService;
    @Inject InMemoryMembershipGateway membershipGateway;
    @Inject CurrentIdentityAssociation identityAssociation;
    @Inject TestClock clock;

    @BeforeEach
    void setUp() {
        membershipGateway.clear();
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD, List.of(new MemberView(USER, SUBJECT, false, false, 1)));
        QuarkusTransaction.requiringNew()
                .run(() -> PointTransaction.delete("householdId", HOUSEHOLD));
    }

    @AfterEach
    void tearDown() {
        clock.useSystemTime();
        membershipGateway.clear();
    }

    private void earned(int points, String when) {
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            PointTransaction row = new PointTransaction();
                            row.id = UUID.randomUUID();
                            row.householdId = HOUSEHOLD;
                            row.userId = USER;
                            row.taskId = UUID.randomUUID();
                            row.completionNo = 1;
                            row.points = points;
                            row.reason = PointReason.task_completed;
                            row.createdAt = Instant.parse(when);
                            row.persist();
                        });
    }

    private Scoreboard board(ScorePeriod period, String yearMonth) {
        return asMember(() -> scoreboardService.scoreboard(HOUSEHOLD, period, yearMonth));
    }

    @Test
    void aTaskDoneJustBeforeLocalMidnightCountsForTheNewMonthInBrussels() {
        clock.fixAt(Instant.parse("2026-04-15T10:00:00Z"));
        earned(5, "2026-03-31T22:30:00Z"); // 00:30 on 1 April in Brussels (CEST, +2)

        assertEquals(0, board(ScorePeriod.month, null).totalPoints(), "UTC household: March");

        membershipGateway.putZone(HOUSEHOLD, BRUSSELS);

        assertEquals(5, board(ScorePeriod.month, null).totalPoints(), "Brussels household: April");
        assertEquals(0, board(ScorePeriod.month, "2026-03").totalPoints());
    }

    @Test
    void aPastMonthIsBrowsedInLocalTime() {
        clock.fixAt(Instant.parse("2026-10-14T10:00:00Z"));
        membershipGateway.putZone(HOUSEHOLD, BRUSSELS);
        earned(4, "2026-03-31T21:59:59Z"); // still 31 March, 23:59:59 local
        earned(6, "2026-03-31T22:00:00Z"); // 1 April, 00:00:00 local

        Scoreboard march = board(ScorePeriod.month, "2026-03");
        Scoreboard april = board(ScorePeriod.month, "2026-04");

        assertEquals(4, march.totalPoints());
        assertEquals("2026-03", march.yearMonth());
        assertEquals(Instant.parse("2026-02-28T23:00:00Z"), march.from());
        assertEquals(Instant.parse("2026-03-31T22:00:00Z"), march.to());
        assertEquals(6, april.totalPoints());
    }

    @Test
    void theWeekStartsOnMondayAtLocalMidnight() {
        clock.fixAt(Instant.parse("2026-10-14T10:00:00Z")); // Wednesday
        earned(3, "2026-10-11T22:30:00Z"); // Monday 12 October 00:30 in Brussels, Sunday in UTC

        assertEquals(0, board(ScorePeriod.week, null).totalPoints(), "UTC: the week before");

        membershipGateway.putZone(HOUSEHOLD, BRUSSELS);
        Scoreboard week = board(ScorePeriod.week, null);

        assertEquals(3, week.totalPoints());
        assertEquals(Instant.parse("2026-10-11T22:00:00Z"), week.from());
        assertEquals(Instant.parse("2026-10-18T22:00:00Z"), week.to());
    }

    @Test
    void theYearTurnsAtLocalNewYear() {
        clock.fixAt(Instant.parse("2026-02-01T10:00:00Z"));
        earned(7, "2025-12-31T23:30:00Z"); // 1 January 2026 in Brussels

        assertEquals(0, board(ScorePeriod.year, null).totalPoints(), "UTC: still 2025");

        membershipGateway.putZone(HOUSEHOLD, BRUSSELS);
        Scoreboard year = board(ScorePeriod.year, null);

        assertEquals(7, year.totalPoints());
        assertEquals("2026", year.yearMonth());
    }

    @Test
    void anOpenWindowIsCutAtItsEndToo() {
        clock.fixAt(Instant.parse("2026-10-14T10:00:00Z"));
        membershipGateway.putZone(HOUSEHOLD, ZoneId.of("America/New_York"));

        Scoreboard year = board(ScorePeriod.year, null);

        assertEquals(Instant.parse("2026-01-01T05:00:00Z"), year.from());
        assertEquals(Instant.parse("2027-01-01T05:00:00Z"), year.to());
    }

    @Test
    void allTimeHasNoBoundsWhateverTheZone() {
        membershipGateway.putZone(HOUSEHOLD, BRUSSELS);
        earned(2, "2020-01-01T00:00:00Z");

        Scoreboard all = board(ScorePeriod.all, null);

        assertEquals(2, all.totalPoints());
        assertEquals(null, all.from());
        assertEquals(null, all.to());
    }

    @Test
    void anUnreachableHouseholdsServiceMakesTheScoreboardUnavailable() {
        membershipGateway.setUnavailable(true);

        assertThrows(
                ScoringException.ServiceUnavailable.class, () -> board(ScorePeriod.month, null));
    }

    private <T> T asMember(Supplier<T> action) {
        SecurityIdentity previous = identityAssociation.getIdentity();
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder()
                        .setPrincipal(() -> SUBJECT.toString())
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
