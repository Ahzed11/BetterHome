package com.betterhome.households;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.households.domain.AccountDeletion;
import com.betterhome.households.domain.AccountDeletionStep;
import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Invitation;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import com.betterhome.households.domain.NotificationOutbox;
import com.betterhome.households.erasure.AccountDeletionProcessor;
import com.betterhome.households.service.AccountDeletionService;
import com.betterhome.households.service.CurrentUserService;
import com.betterhome.households.service.HouseholdService;
import com.betterhome.households.service.InvitationService;
import com.betterhome.households.service.MembershipService;
import com.betterhome.households.service.OutboxService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Account deletion (spec §9, T-0032) through the real services and PostgreSQL. The other services
 * and the identity provider are replaced by recording stand-ins.
 */
@QuarkusTest
class AccountDeletionTest {

    @Inject SecurityTestSupport security;
    @Inject CurrentUserService currentUserService;
    @Inject HouseholdService householdService;
    @Inject InvitationService invitationService;
    @Inject MembershipService membershipService;
    @Inject AccountDeletionService accountDeletionService;
    @Inject AccountDeletionProcessor processor;
    @Inject OutboxService outboxService;
    @Inject TestClock clock;
    @Inject InMemoryIdentityAdmin identity;
    @Inject RecordingAnonymizeClients services;

    private RecordingAnonymizeClient tasks;
    private RecordingAnonymizeClient scoring;
    private RecordingAnonymizeClient lists;
    private RecordingAnonymizeClient notifications;

    private UUID leaverSubject;
    private UUID otherSubject;
    private UUID leaverId;
    private UUID otherId;
    private String leaverEmail;
    private String otherEmail;

    @BeforeEach
    void setUp() {
        clock.reset();
        identity.reset();
        services.reset();
        tasks = services.tasks;
        scoring = services.scoring;
        lists = services.lists;
        notifications = services.notifications;
        leaverSubject = UUID.randomUUID();
        otherSubject = UUID.randomUUID();
        leaverEmail = "leaver-" + leaverSubject + "@example.com";
        leaverId = syncUser(leaverSubject, leaverEmail, "Lea", "Ver");
        otherEmail = "other-" + otherSubject + "@example.com";
        otherId = syncUser(otherSubject, otherEmail, "Oto", "Her");
    }

    @AfterEach
    void restoreClock() {
        clock.reset();
    }

    private UUID syncUser(UUID subject, String email, String given, String family) {
        return security.asUser(
                        subject, () -> currentUserService.sync(email, given, family, "fr", "UTC"))
                .id;
    }

    private UUID createHousehold(UUID owner, String name) {
        return security.asUser(owner, () -> householdService.create(name, "UTC")).id;
    }

    private void join(
            UUID householdId, UUID admin, UUID joiner, String email, MembershipRole role) {
        String token =
                security.asUser(admin, () -> invitationService.create(householdId, email, role))
                        .token;
        security.asUser(joiner, () -> invitationService.accept(token));
    }

    private AppUser profile(UUID id) {
        return QuarkusTransaction.requiringNew().call(() -> AppUser.findById(id));
    }

    private boolean isActiveMember(UUID householdId, UUID userId) {
        return QuarkusTransaction.requiringNew()
                .call(() -> Membership.findActive(householdId, userId).isPresent());
    }

    private AccountDeletion deletion(UUID userId) {
        return QuarkusTransaction.requiringNew().call(() -> AccountDeletion.findById(userId));
    }

    private Set<String> confirmedTargets(UUID userId) {
        return QuarkusTransaction.requiringNew()
                .call(() -> AccountDeletionStep.doneTargets(userId));
    }

    @Test
    void deletingTheAccountLeavesEveryHouseholdAnonymizesTheProfileAndTellsEveryTarget() {
        UUID shared = createHousehold(otherSubject, "Shared");
        join(shared, otherSubject, leaverSubject, leaverEmail, MembershipRole.member);
        UUID second = createHousehold(otherSubject, "Second");
        join(second, otherSubject, leaverSubject, leaverEmail, MembershipRole.admin);

        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        assertFalse(isActiveMember(shared, leaverId));
        assertFalse(isActiveMember(second, leaverId));
        assertTrue(isActiveMember(shared, otherId));
        AppUser profile = profile(leaverId);
        assertNotNull(profile.deletedAt);
        assertEquals("", profile.givenName);
        assertEquals("", profile.familyName);
        assertFalse(profile.email.contains("leaver"));
        assertEquals(leaverSubject, profile.authSubject);
        for (RecordingAnonymizeClient client : services.all()) {
            assertEquals(java.util.List.of(leaverId), client.calls());
        }
        assertEquals(java.util.List.of(leaverSubject), identity.deleted());
        assertNotNull(deletion(leaverId).completedAt);
        assertEquals(
                Set.of("tasks", "scoring", "lists", "notifications", "identity"),
                confirmedTargets(leaverId));
        assertTrue(householdIsActive(shared));
    }

    private boolean householdIsActive(UUID id) {
        return QuarkusTransaction.requiringNew()
                .call(() -> Household.findActiveById(id).isPresent());
    }

    @Test
    void theOnlyAdminOfAHouseholdWithOthersCannotDeleteUntilHandingOver() {
        UUID household = createHousehold(leaverSubject, "Mine");
        join(household, leaverSubject, otherSubject, otherEmail, MembershipRole.member);

        HouseholdException.Conflict refused =
                assertThrows(
                        HouseholdException.Conflict.class,
                        () ->
                                security.asUser(
                                        leaverSubject,
                                        () -> accountDeletionService.deleteMyAccount()));

        assertTrue(refused.getMessage().contains("only admin"));
        assertTrue(isActiveMember(household, leaverId));
        assertNull(profile(leaverId).deletedAt);
        assertEquals(leaverEmail, profile(leaverId).email);
        assertNull(deletion(leaverId));
        for (RecordingAnonymizeClient client : services.all()) {
            assertEquals(0, client.calls().size());
        }
        assertEquals(0, identity.deleted().size());

        security.asUser(
                leaverSubject,
                () -> membershipService.changeRole(household, otherId, MembershipRole.admin));
        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        assertFalse(isActiveMember(household, leaverId));
        assertTrue(householdIsActive(household));
        assertNotNull(profile(leaverId).deletedAt);
    }

    @Test
    void anAdminWhoSharesTheRoleCanDeleteWithoutHandingOver() {
        UUID household = createHousehold(leaverSubject, "Co-admins");
        join(household, leaverSubject, otherSubject, otherEmail, MembershipRole.admin);

        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        assertFalse(isActiveMember(household, leaverId));
        assertTrue(householdIsActive(household));
        assertEquals(
                1L,
                QuarkusTransaction.requiringNew()
                        .call(() -> Membership.countActiveAdmins(household)));
    }

    @Test
    void aHouseholdWhereTheUserIsTheOnlyMemberIsDeletedWithTheAccount() {
        UUID alone = createHousehold(leaverSubject, "Alone");

        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        assertFalse(householdIsActive(alone));
        assertFalse(isActiveMember(alone, leaverId));
        assertNotNull(deletion(leaverId).completedAt);
    }

    @Test
    void aServiceThatIsDownIsRetriedAloneAfterTheBackoffAndTheOthersAreNotCalledAgain() {
        tasks.failWith(new ProcessingException("connection refused"));
        scoring.failWith(new WebApplicationException(Response.status(503).build()));

        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        AccountDeletion pending = deletion(leaverId);
        assertNull(pending.completedAt);
        assertEquals(1, pending.attempts);
        assertEquals(Set.of("lists", "notifications", "identity"), confirmedTargets(leaverId));
        assertNotNull(profile(leaverId).deletedAt);

        assertFalse(processor.process(leaverId), "not due before the backoff has passed");
        assertEquals(1, tasks.calls().size());

        tasks.failWith(null);
        clock.advance(Duration.ofMinutes(1));
        assertFalse(processor.process(leaverId), "scoring still fails");
        assertEquals(2, tasks.calls().size());
        assertEquals(2, scoring.calls().size());

        scoring.failWith(null);
        clock.advance(Duration.ofMinutes(5));
        assertTrue(processor.process(leaverId));

        assertEquals(3, scoring.calls().size());
        assertEquals(2, tasks.calls().size());
        assertEquals(1, lists.calls().size());
        assertEquals(1, notifications.calls().size());
        assertEquals(1, identity.deleted().size());
        assertEquals(
                Set.of("tasks", "scoring", "lists", "notifications", "identity"),
                confirmedTargets(leaverId));
        assertNotNull(deletion(leaverId).completedAt);
    }

    @Test
    void anUnavailableIdentityProviderIsRetriedLikeAService() {
        identity.setDown(true);

        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        assertNull(deletion(leaverId).completedAt);
        assertEquals(
                Set.of("tasks", "scoring", "lists", "notifications"), confirmedTargets(leaverId));

        identity.setDown(false);
        clock.advance(Duration.ofMinutes(1));
        assertTrue(processor.process(leaverId));
        assertEquals(java.util.List.of(leaverSubject), identity.deleted());
    }

    @Test
    void theSchedulerPathPicksUpADeletionThatIsDue() {
        tasks.failWith(new ProcessingException("connection refused"));
        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());
        tasks.failWith(null);
        clock.advance(Duration.ofMinutes(1));

        assertTrue(processor.processDue(50) >= 1);

        assertNotNull(deletion(leaverId).completedAt);
    }

    @Test
    void askingAgainAfterTheDeletionCompletedChangesNothing() {
        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        for (RecordingAnonymizeClient client : services.all()) {
            assertEquals(1, client.calls().size());
        }
        assertEquals(1, identity.deleted().size());
    }

    @Test
    void anAccountThatWasNeverSyncedCannotBeDeleted() {
        UUID stranger = UUID.randomUUID();

        assertThrows(
                HouseholdException.NotFound.class,
                () -> security.asUser(stranger, () -> accountDeletionService.deleteMyAccount()));
    }

    @Test
    void aTokenThatOutlivesTheDeletionCannotCreateTheProfileAgain() {
        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        assertThrows(
                HouseholdException.Forbidden.class,
                () -> syncUser(leaverSubject, leaverEmail, "Lea", "Ver"));
        assertNotNull(profile(leaverId).deletedAt);
    }

    @Test
    void queuedEventsAndInvitationsToTheUsersAddressGoWithTheAccount() {
        UUID household = createHousehold(otherSubject, "Inviting");
        UUID queued = outboxService.enqueue(household, leaverId, "marked_away", Map.of());
        UUID othersQueued = outboxService.enqueue(household, otherId, "marked_away", Map.of());
        security.asUser(
                otherSubject,
                () -> invitationService.create(household, leaverEmail, MembershipRole.member));

        security.asUser(leaverSubject, () -> accountDeletionService.deleteMyAccount());

        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            assertNull(NotificationOutbox.findById(queued));
                            assertNotNull(NotificationOutbox.findById(othersQueued));
                            assertEquals(0L, Invitation.count("lower(email) = ?1", leaverEmail));
                        });
    }
}
