package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.tasks.domain.NotificationOutbox;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.ledger.InMemoryPointsLedgerClient;
import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import com.betterhome.tasks.service.ReminderService;
import com.betterhome.tasks.service.TaskService;
import com.betterhome.tasks.service.TemplateService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Which task events reach the outbox, for whom, and when they must not (spec §5). */
@QuarkusTest
class NotificationProducersTest {

    private static final Instant NOW = Instant.parse("2026-10-14T10:00:00Z");
    private static final UUID HOUSEHOLD = UUID.fromString("cccccccc-0000-0000-0000-000000000001");
    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("c1111111-1111-1111-1111-111111111111");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("c2222222-2222-2222-2222-222222222222");
    private static final UUID OTHER_SUBJECT =
            UUID.fromString("c3333333-3333-3333-3333-333333333333");
    private static final UUID ADMIN_USER = UUID.fromString("caaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("cbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    private static final UUID OTHER_USER = UUID.fromString("cccccccc-cccc-cccc-cccc-cccccccccccc");

    @Inject TemplateService templateService;
    @Inject TaskService taskService;
    @Inject ReminderService reminderService;
    @Inject InMemoryMembershipGateway membershipGateway;
    @Inject InMemoryPointsLedgerClient ledger;
    @Inject CurrentIdentityAssociation identityAssociation;
    @Inject TestClock clock;

    private TaskTemplate template;

    @BeforeEach
    void setUp() {
        clock.fixAt(NOW);
        ledger.clear();
        ledger.setUnavailable(false);
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, false, 2),
                        new MemberView(OTHER_USER, OTHER_SUBJECT, false, false, 3)));
        // The overdue job looks at every household, so start from an empty task table.
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            NotificationOutbox.deleteAll();
                            Task.deleteAll();
                        });
        template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Bins", null, "", 5, 2, 60));
    }

    @AfterEach
    void tearDown() {
        clock.useSystemTime();
    }

    private List<NotificationOutbox> queued() {
        return QuarkusTransaction.requiringNew()
                .call(() -> NotificationOutbox.<NotificationOutbox>listAll());
    }

    private Task openTaskFor(UUID assignee, Instant due) {
        Task task =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.createOpen(HOUSEHOLD, template.id, assignee, due));
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
        return task;
    }

    private void assertSingleEvent(String type, UUID recipient, Task task) {
        List<NotificationOutbox> rows = queued();
        assertEquals(1, rows.size(), rows.toString());
        NotificationOutbox row = rows.getFirst();
        assertEquals(type, row.type);
        assertEquals(recipient, row.userId);
        assertEquals(HOUSEHOLD, row.householdId);
        assertTrue(row.payloadJson.contains("\"taskTitle\":\"Bins\""), row.payloadJson);
        assertTrue(row.payloadJson.contains("\"taskId\":\"" + task.id + "\""), row.payloadJson);
    }

    // task_assigned

    @Test
    void anAdminAssigningATaskToSomeoneElseTellsThem() {
        Task task =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                taskService.createOpen(
                                        HOUSEHOLD,
                                        template.id,
                                        MEMBER_USER,
                                        NOW.plusSeconds(3600)));

        assertSingleEvent("task_assigned", MEMBER_USER, task);
    }

    @Test
    void anAdminAssigningATaskToThemselvesTellsNobody() {
        asUser(
                ADMIN_SUBJECT,
                () ->
                        taskService.createOpen(
                                HOUSEHOLD, template.id, ADMIN_USER, NOW.plusSeconds(3600)));

        assertTrue(queued().isEmpty());
    }

    // task_reassigned

    @Test
    void reassigningTellsTheNewAssignee() {
        Task task = openTaskFor(MEMBER_USER, NOW.plusSeconds(3600));

        Task moved = asUser(ADMIN_SUBJECT, () -> taskService.reassign(HOUSEHOLD, task.id));

        assertEquals(OTHER_USER, moved.assigneeId);
        assertSingleEvent("task_reassigned", OTHER_USER, task);
    }

    @Test
    void reassigningToTheActingAdminTellsNobody() {
        Task task = openTaskFor(OTHER_USER, NOW.plusSeconds(3600));

        Task moved = asUser(ADMIN_SUBJECT, () -> taskService.reassign(HOUSEHOLD, task.id));

        assertEquals(ADMIN_USER, moved.assigneeId);
        assertTrue(queued().isEmpty());
    }

    // dismissed

    @Test
    void anAdminDismissingSomeoneElsesTaskTellsTheAssignee() {
        Task task = openTaskFor(MEMBER_USER, NOW.plusSeconds(3600));

        asUser(ADMIN_SUBJECT, () -> taskService.dismiss(HOUSEHOLD, task.id));

        assertSingleEvent("dismissed", MEMBER_USER, task);
    }

    @Test
    void dismissingYourOwnTaskTellsNobody() {
        Task task = openTaskFor(MEMBER_USER, NOW.plusSeconds(3600));

        asUser(MEMBER_SUBJECT, () -> taskService.dismiss(HOUSEHOLD, task.id));

        assertTrue(queued().isEmpty());
    }

    @Test
    void aDismissalThatIsNotAllowedQueuesNothing() {
        Task task = openTaskFor(MEMBER_USER, NOW.plusSeconds(3600));

        assertThrows(
                TaskException.Forbidden.class,
                () -> asUser(OTHER_SUBJECT, () -> taskService.dismiss(HOUSEHOLD, task.id)));

        assertTrue(queued().isEmpty());
    }

    // reverted

    private Task doneTask(Instant due) {
        Task open = openTaskFor(MEMBER_USER, due);
        asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, open.id));
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
        return open;
    }

    @Test
    void aRevertThatReopensTheTaskTellsTheAssignee() {
        Task task = doneTask(NOW.plusSeconds(3600));

        asUser(ADMIN_SUBJECT, () -> taskService.revert(HOUSEHOLD, task.id, "Not clean"));

        assertSingleEvent("reverted", MEMBER_USER, task);
    }

    @Test
    void aRevertThatDismissesBecauseTheDateHasPassedTellsNobody() {
        Task task = doneTask(NOW.plusSeconds(3600));
        clock.fixAt(NOW.plus(Duration.ofHours(2)));

        asUser(ADMIN_SUBJECT, () -> taskService.revert(HOUSEHOLD, task.id, "Not clean"));

        assertTrue(queued().isEmpty(), "spec 3.3: push only if reopened with a future deadline");
    }

    @Test
    void aRevertThatFailsAtTheLedgerLeavesNoEventBehind() {
        Task task = doneTask(NOW.plusSeconds(3600));
        ledger.setUnavailable(true);

        assertThrows(
                TaskException.ServiceUnavailable.class,
                () ->
                        asUser(
                                ADMIN_SUBJECT,
                                () -> taskService.revert(HOUSEHOLD, task.id, "Not clean")));

        assertTrue(queued().isEmpty(), "no event for a change that was rolled back");
    }

    // overdue

    @Test
    void aTaskPastItsDueDateTellsItsAssigneeOnce() {
        Task task = openTaskFor(MEMBER_USER, NOW.plusSeconds(60));
        clock.fixAt(NOW.plusSeconds(61));

        assertEquals(1, reminderService.sendOverdueNotices(10));
        assertEquals(0, reminderService.sendOverdueNotices(10), "only once per task");

        assertSingleEvent("overdue", MEMBER_USER, task);
        Task stored = QuarkusTransaction.requiringNew().call(() -> Task.<Task>findById(task.id));
        assertNotNull(stored.overdueNotifiedAt);
    }

    @Test
    void aTaskNotYetDueIsNotOverdue() {
        openTaskFor(MEMBER_USER, NOW.plusSeconds(60));

        assertEquals(0, reminderService.sendOverdueNotices(10));
        assertTrue(queued().isEmpty());
    }

    @Test
    void aTaskWithoutADueDateIsNeverOverdue() {
        Task task = openTaskFor(MEMBER_USER, null);
        QuarkusTransaction.requiringNew()
                .run(() -> Task.update("dueAt = null where id = ?1", task.id));
        clock.fixAt(NOW.plus(Duration.ofDays(30)));

        assertEquals(0, reminderService.sendOverdueNotices(10));
    }

    @Test
    void aDoneOrDismissedTaskIsNotOverdue() {
        Task done = doneTask(NOW.plusSeconds(60));
        Task dismissed = openTaskFor(MEMBER_USER, NOW.plusSeconds(60));
        asUser(MEMBER_SUBJECT, () -> taskService.dismiss(HOUSEHOLD, dismissed.id));
        QuarkusTransaction.requiringNew().run(() -> NotificationOutbox.deleteAll());
        clock.fixAt(NOW.plusSeconds(120));

        assertEquals(0, reminderService.sendOverdueNotices(10));
        assertNull(
                QuarkusTransaction.requiringNew()
                        .call(() -> Task.<Task>findById(done.id))
                        .overdueNotifiedAt);
    }

    @Test
    void theLimitBoundsOneRun() {
        for (int i = 0; i < 3; i++) {
            openTaskFor(MEMBER_USER, NOW.plusSeconds(60));
        }
        clock.fixAt(NOW.plusSeconds(61));

        assertEquals(2, reminderService.sendOverdueNotices(2));
        assertEquals(1, reminderService.sendOverdueNotices(2));
    }

    @Test
    void severalReplicasNeverQueueTheSameNoticeTwice() throws Exception {
        for (int i = 0; i < 20; i++) {
            openTaskFor(MEMBER_USER, NOW.plusSeconds(60));
        }
        clock.fixAt(NOW.plusSeconds(61));

        ExecutorService pool = Executors.newFixedThreadPool(4);
        int total = 0;
        try {
            List<Future<Integer>> runs =
                    List.of(
                            pool.submit(() -> reminderService.sendOverdueNotices(20)),
                            pool.submit(() -> reminderService.sendOverdueNotices(20)),
                            pool.submit(() -> reminderService.sendOverdueNotices(20)),
                            pool.submit(() -> reminderService.sendOverdueNotices(20)));
            for (Future<Integer> run : runs) {
                total += run.get(60, TimeUnit.SECONDS);
            }
        } finally {
            pool.shutdownNow();
        }

        assertEquals(20, total);
        assertEquals(20, queued().size(), "one notice per task, no duplicates");
    }

    @Test
    void severalReplicasNeverQueueTheSameReminderTwice() throws Exception {
        // Default household settings remind at 08:00 on the due date: these are due for it at
        // 10:00.
        for (int i = 0; i < 20; i++) {
            openTaskFor(MEMBER_USER, NOW.plusSeconds(7200));
        }

        ExecutorService pool = Executors.newFixedThreadPool(4);
        try {
            List<Future<Integer>> runs =
                    List.of(
                            pool.submit(() -> reminderService.sendDueReminders()),
                            pool.submit(() -> reminderService.sendDueReminders()),
                            pool.submit(() -> reminderService.sendDueReminders()),
                            pool.submit(() -> reminderService.sendDueReminders()));
            int total = 0;
            for (Future<Integer> run : runs) {
                total += run.get(60, TimeUnit.SECONDS);
            }
            assertEquals(20, total);
        } finally {
            pool.shutdownNow();
        }

        assertEquals(20, queued().size(), "one reminder per task, no duplicates");
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
