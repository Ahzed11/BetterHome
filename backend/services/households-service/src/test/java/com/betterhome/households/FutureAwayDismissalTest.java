package com.betterhome.households;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import com.betterhome.households.service.AwayStartDismissal;
import com.betterhome.households.service.CurrentUserService;
import com.betterhome.households.service.HouseholdService;
import com.betterhome.households.service.InvitationService;
import com.betterhome.households.service.MembershipService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class FutureAwayDismissalTest {

    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("66666666-6666-6666-6666-666666666666");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("77777777-7777-7777-7777-777777777777");

    @Inject SecurityTestSupport security;
    @Inject CurrentUserService currentUserService;
    @Inject HouseholdService householdService;
    @Inject InvitationService invitationService;
    @Inject MembershipService membershipService;
    @Inject AwayStartDismissal awayStartDismissal;
    @Inject TestClock clock;
    @Inject @RestClient RecordingTasksInternalClient internalClient;
    @Inject @RestClient RecordingTasksClient userClient;

    private UUID householdId;
    private UUID adminId;
    private UUID memberId;

    @BeforeEach
    void setUp() {
        clock.reset();
        internalClient.reset();
        userClient.reset();
        settlePeriodsLeftByOtherTests();
        security.asUser(
                MEMBER_SUBJECT,
                () -> currentUserService.sync("future-member@example.com", "Mo", "M", "en", "UTC"));
        adminId =
                security.asUser(
                                ADMIN_SUBJECT,
                                () ->
                                        currentUserService.sync(
                                                "future-admin@example.com",
                                                "Ada",
                                                "A",
                                                "en",
                                                "UTC"))
                        .id;
        householdId = security.asUser(ADMIN_SUBJECT, () -> householdService.create("F", "UTC")).id;
        var invitation =
                security.asUser(
                        ADMIN_SUBJECT,
                        () ->
                                invitationService.create(
                                        householdId,
                                        "future-member@example.com",
                                        MembershipRole.member));
        memberId =
                security.asUser(MEMBER_SUBJECT, () -> invitationService.accept(invitation.token))
                        .userId;
    }

    /** The database is shared by the whole suite; only this test's periods must be due. */
    private static void settlePeriodsLeftByOtherTests() {
        QuarkusTransaction.requiringNew()
                .run(
                        () ->
                                Membership.update(
                                        "awayTasksDismissedAt = ?1 where awayFrom is not null"
                                                + " and awayTasksDismissedAt is null",
                                        Instant.now()));
    }

    @AfterEach
    void restoreClock() {
        clock.reset();
    }

    @Test
    void openTasksAreDismissedWhenAFutureAwayPeriodStarts() {
        scheduleAway(Duration.ofDays(2), null);

        assertEquals(0, awayStartDismissal.dismissDue());
        assertEquals(0, internalClient.calls().size());

        clock.advance(Duration.ofDays(2).plusMinutes(1));

        assertEquals(1, awayStartDismissal.dismissDue());
        assertEquals(1, internalClient.calls().size());
        var call = internalClient.calls().get(0);
        assertEquals(householdId, call.householdId());
        assertEquals(memberId, call.userId());
        assertEquals(adminId, call.dismissedBy());
        assertNotNull(membership().awayTasksDismissedAt);
    }

    @Test
    void aPeriodAlreadyHandledIsNotRepeated() {
        scheduleAway(Duration.ofHours(1), null);
        clock.advance(Duration.ofHours(2));

        assertEquals(1, awayStartDismissal.dismissDue());
        assertEquals(0, awayStartDismissal.dismissDue());

        assertEquals(1, internalClient.calls().size());
    }

    @Test
    void awayStartingNowIsDismissedByTheRequestAndNotRepeatedByTheJob() {
        security.asUser(
                ADMIN_SUBJECT, () -> membershipService.setAway(householdId, memberId, null, null));

        assertEquals(1, userClient.calls().size());
        assertNotNull(membership().awayTasksDismissedAt);
        assertEquals(0, awayStartDismissal.dismissDue());
        assertEquals(0, internalClient.calls().size());
    }

    @Test
    void reschedulingAwayMakesTheNewPeriodDueAgain() {
        scheduleAway(Duration.ofHours(1), null);
        clock.advance(Duration.ofHours(2));
        awayStartDismissal.dismissDue();

        scheduleAway(Duration.ofHours(1), null);
        assertNull(membership().awayTasksDismissedAt);
        clock.advance(Duration.ofHours(2));

        assertEquals(1, awayStartDismissal.dismissDue());
        assertEquals(2, internalClient.calls().size());
    }

    @Test
    void clearedAwayIsNeverDismissed() {
        scheduleAway(Duration.ofHours(1), null);
        security.asUser(ADMIN_SUBJECT, () -> membershipService.clearAway(householdId, memberId));
        clock.advance(Duration.ofHours(2));

        assertEquals(0, awayStartDismissal.dismissDue());
        assertEquals(0, internalClient.calls().size());
    }

    @Test
    void anAwayPeriodThatAlreadyEndedIsNeverDismissed() {
        scheduleAway(Duration.ofHours(1), Duration.ofHours(2));
        clock.advance(Duration.ofDays(1));

        assertEquals(0, awayStartDismissal.dismissDue());
        assertEquals(0, internalClient.calls().size());
    }

    @Test
    void aMemberWhoLeftBeforeTheStartIsNeverDismissed() {
        scheduleAway(Duration.ofHours(1), null);
        security.asUser(MEMBER_SUBJECT, () -> membershipService.leave(householdId));
        clock.advance(Duration.ofHours(2));

        assertEquals(0, awayStartDismissal.dismissDue());
        assertEquals(0, internalClient.calls().size());
    }

    @Test
    void anUnreachableTasksServiceLeavesThePeriodDueForTheNextRun() {
        scheduleAway(Duration.ofHours(1), null);
        clock.advance(Duration.ofHours(2));
        internalClient.failWith(new ProcessingException("connection refused"));

        assertEquals(0, awayStartDismissal.dismissDue());
        assertNull(membership().awayTasksDismissedAt);

        internalClient.failWith(null);

        assertEquals(1, awayStartDismissal.dismissDue());
        assertNotNull(membership().awayTasksDismissedAt);
    }

    @Test
    void aRefusalFromTasksServiceLeavesThePeriodDue() {
        scheduleAway(Duration.ofHours(1), null);
        clock.advance(Duration.ofHours(2));
        internalClient.failWith(new jakarta.ws.rs.ForbiddenException("refused"));

        assertEquals(0, awayStartDismissal.dismissDue());
        assertNull(membership().awayTasksDismissedAt);
    }

    @Test
    void twoReplicasNeverHandleTheSamePeriod() throws Exception {
        scheduleAway(Duration.ofHours(1), null);
        clock.advance(Duration.ofHours(2));
        CountDownLatch firstIsCalling = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        internalClient.duringCall(
                () -> {
                    firstIsCalling.countDown();
                    awaitQuietly(release);
                });

        CompletableFuture<Integer> first =
                CompletableFuture.supplyAsync(awayStartDismissal::dismissDue);
        assertEquals(true, firstIsCalling.await(10, TimeUnit.SECONDS));

        assertEquals(0, awayStartDismissal.dismissDue());
        release.countDown();

        assertEquals(1, first.get(10, TimeUnit.SECONDS));
        assertEquals(1, internalClient.calls().size());
    }

    private void scheduleAway(Duration startsIn, Duration endsAfterStart) {
        var from = clock.now().plus(startsIn);
        var until = endsAfterStart == null ? null : from.plus(endsAfterStart);
        security.asUser(
                ADMIN_SUBJECT, () -> membershipService.setAway(householdId, memberId, from, until));
    }

    private Membership membership() {
        return QuarkusTransaction.requiringNew()
                .call(() -> Membership.findActive(householdId, memberId).orElseThrow());
    }

    private static void awaitQuietly(CountDownLatch latch) {
        try {
            latch.await(10, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new HouseholdException.ServiceUnavailable("interrupted");
        }
    }
}
