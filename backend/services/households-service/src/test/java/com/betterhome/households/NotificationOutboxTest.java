package com.betterhome.households;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.Clock;
import com.betterhome.common.NotificationEvent;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.MembershipRole;
import com.betterhome.households.domain.NotificationOutbox;
import com.betterhome.households.notifications.ScriptedNotificationsGateway;
import com.betterhome.households.service.CurrentUserService;
import com.betterhome.households.service.HouseholdService;
import com.betterhome.households.service.InvitationService;
import com.betterhome.households.service.MembershipService;
import com.betterhome.households.service.OutboxRelay;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The events households produces for notifications-service, and when it does not. */
@QuarkusTest
class NotificationOutboxTest {

    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("66666666-6666-6666-6666-666666666666");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("77777777-7777-7777-7777-777777777777");

    @Inject SecurityTestSupport security;
    @Inject CurrentUserService currentUserService;
    @Inject HouseholdService householdService;
    @Inject InvitationService invitationService;
    @Inject MembershipService membershipService;
    @Inject OutboxRelay relay;
    @Inject ScriptedNotificationsGateway gateway;
    @Inject Clock clock;
    @Inject @RestClient RecordingTasksClient tasksClient;

    private UUID householdId;
    private UUID memberId;

    @BeforeEach
    void setUp() {
        tasksClient.reset();
        gateway.reset();
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
        security.asUser(
                MEMBER_SUBJECT,
                () -> currentUserService.sync("outbox-member@example.com", "Mo", "M", "fr", "UTC"));
        security.asUser(
                ADMIN_SUBJECT,
                () -> currentUserService.sync("outbox-admin@example.com", "Ada", "A", "en", "UTC"));
        householdId =
                security.asUser(ADMIN_SUBJECT, () -> householdService.create("Seneffe", "UTC")).id;
        var invitation =
                security.asUser(
                        ADMIN_SUBJECT,
                        () ->
                                invitationService.create(
                                        householdId,
                                        "outbox-member@example.com",
                                        MembershipRole.member));
        memberId =
                security.asUser(MEMBER_SUBJECT, () -> invitationService.accept(invitation.token))
                        .userId;
        // The invitation above queued its own event; these tests look at what comes next.
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
    }

    private List<NotificationOutbox> rows() {
        return QuarkusTransaction.requiringNew()
                .call(() -> NotificationOutbox.<NotificationOutbox>listAll());
    }

    @Test
    void markingAMemberAwayQueuesOneEventForThatMember() {
        security.asUser(
                ADMIN_SUBJECT, () -> membershipService.setAway(householdId, memberId, null, null));

        List<NotificationOutbox> queued = rows();
        assertEquals(1, queued.size());
        NotificationOutbox row = queued.getFirst();
        assertEquals("marked_away", row.type);
        assertEquals(memberId, row.userId);
        assertEquals(householdId, row.householdId);
        assertEquals("{}", row.payloadJson);
        assertNotNull(row.availableAt);
    }

    @Test
    void anAwayPeriodStartingLaterStillTellsTheMember() {
        security.asUser(
                ADMIN_SUBJECT,
                () ->
                        membershipService.setAway(
                                householdId, memberId, clock.now().plus(Duration.ofDays(2)), null));

        assertEquals(1, rows().size());
    }

    @Test
    void clearingAwayQueuesNothing() {
        security.asUser(
                ADMIN_SUBJECT, () -> membershipService.setAway(householdId, memberId, null, null));
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());

        security.asUser(ADMIN_SUBJECT, () -> membershipService.clearAway(householdId, memberId));

        assertTrue(rows().isEmpty());
    }

    @Test
    void anAwayChangeThatFailsLeavesNoEventBehind() {
        tasksClient.failWith(new ProcessingException("connection refused"));

        security.asUser(
                ADMIN_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.ServiceUnavailable.class,
                                () ->
                                        membershipService.setAway(
                                                householdId, memberId, null, null)));

        assertTrue(rows().isEmpty(), "no event for a change that did not happen");
    }

    @Test
    void aRejectedAwayChangeQueuesNothing() {
        security.asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                HouseholdException.Forbidden.class,
                                () ->
                                        membershipService.setAway(
                                                householdId, memberId, null, null)));

        assertTrue(rows().isEmpty());
    }

    @Test
    void invitingSomeoneWhoHasAnAccountQueuesAnInvitationEventWithTheHouseholdName() {
        security.asUser(
                ADMIN_SUBJECT,
                () ->
                        invitationService.create(
                                householdId, "Outbox-Member@Example.com", MembershipRole.member));

        List<NotificationOutbox> queued = rows();
        assertEquals(1, queued.size(), "the email is matched whatever its case");
        assertEquals("invitation", queued.getFirst().type);
        assertEquals(memberId, queued.getFirst().userId);
        assertEquals("{\"householdName\":\"Seneffe\"}", queued.getFirst().payloadJson);
    }

    @Test
    void invitingSomeoneWithoutAnAccountQueuesNothing() {
        security.asUser(
                ADMIN_SUBJECT,
                () ->
                        invitationService.create(
                                householdId, "nobody-yet@example.com", MembershipRole.member));

        assertTrue(rows().isEmpty(), "there is nobody to push to yet");
    }

    @Test
    void theRelayHandsTheEventsOverWithTheContractFields() {
        security.asUser(
                ADMIN_SUBJECT, () -> membershipService.setAway(householdId, memberId, null, null));
        security.asUser(
                ADMIN_SUBJECT,
                () ->
                        invitationService.create(
                                householdId, "outbox-member@example.com", MembershipRole.member));

        assertEquals(2, relay.relayDue(10));

        List<NotificationEvent> sent = gateway.delivered();
        assertEquals(
                List.of("marked_away", "invitation"), sent.stream().map(e -> e.type()).toList());
        for (NotificationEvent event : sent) {
            assertTrue(event.idempotencyKey().startsWith("households:"));
            assertEquals(memberId, event.userId());
            assertEquals(householdId, event.householdId());
        }
        assertEquals("Seneffe", sent.get(1).payload().get("householdName"));
        assertTrue(sent.get(0).payload().isEmpty());
    }
}
