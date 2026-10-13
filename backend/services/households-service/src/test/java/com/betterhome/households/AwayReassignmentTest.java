package com.betterhome.households;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.Clock;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import com.betterhome.households.service.CurrentUserService;
import com.betterhome.households.service.HouseholdService;
import com.betterhome.households.service.InvitationService;
import com.betterhome.households.service.MembershipService;
import io.quarkus.oidc.AccessTokenCredential;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.util.UUID;
import java.util.function.Supplier;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AwayReassignmentTest {

    private static final UUID ADMIN_SUBJECT = UUID.fromString("44444444-4444-4444-4444-444444444444");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("55555555-5555-5555-5555-555555555555");
    private static final String ADMIN_TOKEN = "admin-access-token";

    @Inject CurrentIdentityAssociation identityAssociation;
    @Inject CurrentUserService currentUserService;
    @Inject HouseholdService householdService;
    @Inject InvitationService invitationService;
    @Inject MembershipService membershipService;
    @Inject Clock clock;
    @Inject @RestClient RecordingTasksClient tasksClient;

    private UUID householdId;
    private UUID memberId;

    @BeforeEach
    void setUp() {
        tasksClient.reset();
        asUser(
                MEMBER_SUBJECT,
                () -> currentUserService.sync("away-member@example.com", "Mo", "M", "en", "UTC"));
        asUser(
                ADMIN_SUBJECT,
                () -> currentUserService.sync("away-admin@example.com", "Ada", "A", "en", "UTC"));
        var household = asUser(ADMIN_SUBJECT, () -> householdService.create("Away", "UTC"));
        householdId = household.id;
        var invitation =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                invitationService.create(
                                        householdId,
                                        "away-member@example.com",
                                        MembershipRole.member));
        var member =
                asUser(
                        MEMBER_SUBJECT,
                        () -> invitationService.accept(invitation.token));
        memberId = member.userId;
    }

    @Test
    void settingAwayAsksTasksServiceToReassignWithTheAdminToken() {
        asUser(ADMIN_SUBJECT, () -> membershipService.setAway(householdId, memberId, null, null));

        assertEquals(1, tasksClient.calls().size());
        var call = tasksClient.calls().get(0);
        assertEquals("Bearer " + ADMIN_TOKEN, call.authorization());
        assertEquals(householdId, call.householdId());
        assertEquals(memberId, call.userId());
    }

    @Test
    void awayStartingLaterDoesNotReassignYet() {
        asUser(
                ADMIN_SUBJECT,
                () ->
                        membershipService.setAway(
                                householdId,
                                memberId,
                                clock.now().plus(Duration.ofDays(2)),
                                null));

        assertEquals(0, tasksClient.calls().size());
    }

    @Test
    void unreachableTasksServiceDoesNotUndoTheAwayChange() {
        tasksClient.failWith(true);

        Membership away =
                asUser(
                        ADMIN_SUBJECT,
                        () -> membershipService.setAway(householdId, memberId, null, null));

        assertEquals(1, tasksClient.calls().size());
        assertTrue(away.isAway(clock.now()));
        assertTrue(
                Membership.findActive(householdId, memberId)
                        .orElseThrow()
                        .isAway(clock.now()));
    }

    @Test
    void rejectedAwayChangeReassignsNothing() {
        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.Forbidden.class,
                                () ->
                                        membershipService.setAway(
                                                householdId, memberId, null, null)));

        assertEquals(0, tasksClient.calls().size());
    }

    private <T> T asUser(UUID authSubject, Supplier<T> action) {
        var previous = identityAssociation.getIdentity();
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder()
                        .setPrincipal(() -> authSubject.toString())
                        .addRole("member")
                        .addCredential(new AccessTokenCredential(ADMIN_TOKEN))
                        .build());
        try {
            return action.get();
        } finally {
            identityAssociation.setIdentity(
                    previous != null
                            ? previous
                            : QuarkusSecurityIdentity.builder().setAnonymous(true).build());
        }
    }
}
