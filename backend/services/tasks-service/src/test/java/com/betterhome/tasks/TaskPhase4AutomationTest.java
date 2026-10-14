package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.tasks.domain.AssignmentMode;
import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.NotificationOutbox;
import com.betterhome.tasks.domain.Rotation;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskRecurrence;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.HouseholdSettings;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import com.betterhome.tasks.notifications.ScriptedNotificationsGateway;
import com.betterhome.tasks.service.OutboxRelay;
import com.betterhome.tasks.service.RecurrenceService;
import com.betterhome.tasks.service.RecurrenceSpawnService;
import com.betterhome.tasks.service.ReminderService;
import com.betterhome.tasks.service.TemplateService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TaskPhase4AutomationTest {

    private static final UUID HOUSEHOLD = UUID.fromString("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID ADMIN_USER = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");

    @Inject TemplateService templateService;

    @Inject RecurrenceService recurrenceService;

    @Inject RecurrenceSpawnService spawnService;

    @Inject ReminderService reminderService;

    @Inject OutboxRelay outboxRelay;
    @Inject ScriptedNotificationsGateway notificationsGateway;

    @Inject InMemoryMembershipGateway membershipGateway;

    @Inject TestClock clock;

    @Inject CurrentIdentityAssociation identityAssociation;

    @AfterEach
    void releaseClock() {
        clock.useSystemTime();
    }

    @BeforeEach
    @Transactional
    void seed() {
        NotificationOutbox.deleteAll();
        Task.deleteAll();
        TaskRecurrence.deleteAll();
        TaskTemplate.deleteAll();
        Rotation.deleteAll();
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, false, 2)));
        membershipGateway.putSettings(
                HOUSEHOLD, new HouseholdSettings("UTC", 0, LocalTime.of(8, 0)));
    }

    @Test
    void spawnSupersedesPreviousAndWritesOutbox() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Bins", "🗑️", "", 5, 2, 60));

        Instant start = Instant.now().minusSeconds(3600);
        asUser(
                ADMIN_SUBJECT,
                () ->
                        recurrenceService.upsert(
                                HOUSEHOLD,
                                template.id,
                                "FREQ=DAILY",
                                AssignmentMode.round_robin,
                                null,
                                start,
                                null));

        assertEquals(1, spawnService.claimAndSpawnDue(1));
        List<Task> firstOpenList =
                Task.list(
                        "householdId = ?1 and templateId = ?2 and status = ?3",
                        HOUSEHOLD,
                        template.id,
                        TaskStatus.open);
        Task firstOpen = firstOpenList.get(0);
        assertEquals(TaskOrigin.recurrence, firstOpen.origin);
        UUID firstId = firstOpen.id;

        int updated =
                QuarkusTransaction.requiringNew()
                        .call(
                                () ->
                                        TaskRecurrence.update(
                                                "nextRunAt = ?1 where householdId = ?2 and templateId = ?3",
                                                Instant.now().minusSeconds(60),
                                                HOUSEHOLD,
                                                template.id));
        assertEquals(1, updated);

        assertEquals(1, spawnService.claimAndSpawnDue(1));
        long dismissed =
                Task.count(
                        "id = ?1 and status = ?2 and dismissalReason = ?3",
                        firstId,
                        TaskStatus.dismissed,
                        DismissalReason.superseded);
        assertEquals(1, dismissed);

        List<Task> stillOpen =
                Task.list(
                        "householdId = ?1 and templateId = ?2 and status = ?3",
                        HOUSEHOLD,
                        template.id,
                        TaskStatus.open);
        assertEquals(1, stillOpen.size());
        assertFalse(stillOpen.getFirst().id.equals(firstId));

        assertTrue(NotificationOutbox.count("type = ?1", "superseded") >= 1);
        assertTrue(NotificationOutbox.count("type = ?1", "task_assigned") >= 2);
        notificationsGateway.reset();
        assertTrue(outboxRelay.relayDue(100) >= 1);
        assertTrue(
                notificationsGateway.delivered().stream()
                        .anyMatch(
                                e ->
                                        e.type().equals("superseded")
                                                && e.payload().containsKey("taskTitle")));
    }

    @Test
    void nobodyAvailableDismissesOccurrence() {
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, true, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, true, 2)));

        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Dust", null, "", 3, 1, 30));
        asUser(
                ADMIN_SUBJECT,
                () ->
                        recurrenceService.upsert(
                                HOUSEHOLD,
                                template.id,
                                "FREQ=DAILY",
                                AssignmentMode.round_robin,
                                null,
                                Instant.now().minusSeconds(120),
                                null));
        assertEquals(1, spawnService.claimAndSpawnDue(1));
        List<Task> tasks =
                Task.list("householdId = ?1 and templateId = ?2", HOUSEHOLD, template.id);
        assertEquals(1, tasks.size());
        assertEquals(TaskStatus.dismissed, tasks.getFirst().status);
        assertEquals(DismissalReason.nobody_available, tasks.getFirst().dismissalReason);
    }

    @Test
    void archiveStopsRecurrence() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Mop", null, "", 2, 1, 30));
        asUser(
                ADMIN_SUBJECT,
                () ->
                        recurrenceService.upsert(
                                HOUSEHOLD,
                                template.id,
                                "FREQ=WEEKLY;BYDAY=MO",
                                AssignmentMode.fixed,
                                MEMBER_USER,
                                Instant.parse("2020-01-06T08:00:00Z"),
                                null));
        asUser(ADMIN_SUBJECT, () -> templateService.archive(HOUSEHOLD, template.id));
        TaskRecurrence recurrence =
                TaskRecurrence.findByTemplate(HOUSEHOLD, template.id).orElseThrow();
        assertNull(recurrence.nextRunAt);
    }

    @Test
    void reminderEnqueuesWhenDue() {
        Instant now = Instant.parse("2026-03-10T12:00:00Z");
        clock.fixAt(now);
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Kitchen", null, "", 2, 1, 30));
        asUser(
                ADMIN_SUBJECT,
                () ->
                        recurrenceService.upsert(
                                HOUSEHOLD,
                                template.id,
                                "FREQ=DAILY",
                                AssignmentMode.round_robin,
                                null,
                                now.minusSeconds(120),
                                null));
        assertEquals(1, spawnService.claimAndSpawnDue(1));
        List<Task> openList =
                Task.list("householdId = ?1 and status = ?2", HOUSEHOLD, TaskStatus.open);
        Task open = openList.get(0);
        QuarkusTransaction.requiringNew()
                .call(
                        () ->
                                Task.update(
                                        "dueAt = ?1, dueReminderSentAt = null where id = ?2",
                                        now.plusSeconds(7200),
                                        open.id));

        int sent = reminderService.sendDueReminders();
        assertEquals(1, sent);
        assertEquals(1, NotificationOutbox.count("type = ?1", "due_reminder"));
        assertEquals(1, Task.count("id = ?1 and dueReminderSentAt is not null", open.id));
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
