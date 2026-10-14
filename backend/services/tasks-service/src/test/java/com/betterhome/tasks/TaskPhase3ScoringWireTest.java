package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.ledger.InMemoryPointsLedgerClient;
import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import com.betterhome.tasks.service.TaskService;
import com.betterhome.tasks.service.TemplateService;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TaskPhase3ScoringWireTest {

    private static final UUID HOUSEHOLD = UUID.fromString("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID ADMIN_USER = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");

    @Inject TemplateService templateService;

    @Inject TaskService taskService;

    @Inject InMemoryMembershipGateway membershipGateway;

    @Inject InMemoryPointsLedgerClient pointsLedgerClient;

    @Inject CurrentIdentityAssociation identityAssociation;

    @BeforeEach
    void seed() {
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, false, 2)));
        pointsLedgerClient.clear();
    }

    @Test
    void completeAndQuickLogAwardLedger() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Dust", null, "", 4, 1, 60));

        Task manual = asUser(MEMBER_SUBJECT, () -> taskService.quickLog(HOUSEHOLD, template.id));
        assertEquals(1, pointsLedgerClient.awards().size());
        assertEquals(4, pointsLedgerClient.balance(MEMBER_USER));
        assertEquals(manual.id, pointsLedgerClient.awards().get(0).taskId());

        Task open =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                taskService.createOpen(
                                        HOUSEHOLD,
                                        template.id,
                                        MEMBER_USER,
                                        Instant.now().plusSeconds(3600)));
        Task done = asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, open.id));
        assertEquals(4, done.pointsAwarded);
        assertEquals(2, pointsLedgerClient.awards().size());
        assertEquals(8, pointsLedgerClient.balance(MEMBER_USER));
        assertTrue(pointsLedgerClient.awards().stream().noneMatch(a -> a.late()));
    }

    @Test
    void revertManualAndOverdueRecurrence() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Mop", null, "", 5, 2, 30));

        Task manual = asUser(MEMBER_SUBJECT, () -> taskService.quickLog(HOUSEHOLD, template.id));
        Task reverted =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.revert(HOUSEHOLD, manual.id, "Logged by mistake"));
        assertEquals(TaskStatus.reverted, reverted.status);
        assertEquals(TaskOrigin.manual, reverted.origin);
        assertNull(reverted.pointsAwarded);
        assertEquals(1, pointsLedgerClient.reversals().size());
        assertEquals(0, pointsLedgerClient.balance(MEMBER_USER));

        Task overdue =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                taskService.createOpen(
                                        HOUSEHOLD,
                                        template.id,
                                        MEMBER_USER,
                                        Instant.parse("2020-01-01T00:00:00Z")));
        asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, overdue.id));
        Task dismissed =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.revert(HOUSEHOLD, overdue.id, "Too late to reopen"));
        assertEquals(TaskStatus.dismissed, dismissed.status);
        assertEquals(DismissalReason.reverted_overdue, dismissed.dismissalReason);

        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.Forbidden.class,
                                () -> taskService.revert(HOUSEHOLD, manual.id, "member cannot")));
    }

    @Test
    void retryingACompletionWhoseAnswerWasLostAwardsOnce() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Wipe", null, "", 3, 1, 60));
        Task open =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                taskService.createOpen(
                                        HOUSEHOLD,
                                        template.id,
                                        MEMBER_USER,
                                        Instant.now().plusSeconds(3600)));
        pointsLedgerClient.failAfterRecordingNextAward();

        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.ServiceUnavailable.class,
                                () -> taskService.complete(HOUSEHOLD, open.id)));
        assertEquals(TaskStatus.open, reload(open.id).status);
        assertEquals(0, reload(open.id).completionNo);

        Task done = asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, open.id));

        assertEquals(TaskStatus.done, done.status);
        assertEquals(1, pointsLedgerClient.awards().size());
        assertEquals(3, pointsLedgerClient.balance(MEMBER_USER));
    }

    @Test
    void aTaskReopenedByAReversionIsAwardedAgainWhenCompletedAgain() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Sweep", null, "", 3, 1, 60));
        Task open =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                taskService.createOpen(
                                        HOUSEHOLD,
                                        template.id,
                                        MEMBER_USER,
                                        Instant.now().plusSeconds(3600)));

        asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, open.id));
        Task reopened = asUser(ADMIN_SUBJECT, () -> taskService.revert(HOUSEHOLD, open.id, "Oops"));
        assertEquals(TaskStatus.open, reopened.status);
        asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, open.id));

        assertEquals(
                List.of(1, 2),
                pointsLedgerClient.awards().stream().map(a -> a.completionNo()).toList());
        assertEquals(3, pointsLedgerClient.balance(MEMBER_USER));
    }

    @Test
    void aLedgerOutageLeavesNoDoneTaskWithoutPoints() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Vacuum", null, "", 3, 1, 60));
        Task open =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                taskService.createOpen(
                                        HOUSEHOLD,
                                        template.id,
                                        MEMBER_USER,
                                        Instant.now().plusSeconds(3600)));
        pointsLedgerClient.setUnavailable(true);

        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.ServiceUnavailable.class,
                                () -> taskService.complete(HOUSEHOLD, open.id)));
        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.ServiceUnavailable.class,
                                () -> taskService.quickLog(HOUSEHOLD, template.id)));

        assertEquals(TaskStatus.open, reload(open.id).status);
        assertEquals(0L, countTasks(template.id, TaskStatus.done));
        assertEquals(0L, countTasks(template.id, TaskStatus.reverted));
        assertTrue(pointsLedgerClient.awards().isEmpty());

        pointsLedgerClient.setUnavailable(false);
        Task done = asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, open.id));
        assertEquals(TaskStatus.done, done.status);
        assertEquals(3, pointsLedgerClient.balance(MEMBER_USER));
    }

    @Test
    void aLedgerOutageLeavesTheDoneTaskDoneOnRevert() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Sweep", null, "", 3, 1, 60));
        Task manual = asUser(MEMBER_SUBJECT, () -> taskService.quickLog(HOUSEHOLD, template.id));
        pointsLedgerClient.setUnavailable(true);

        asUser(
                ADMIN_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.ServiceUnavailable.class,
                                () -> taskService.revert(HOUSEHOLD, manual.id, "Mistake")));

        Task reloaded = reload(manual.id);
        assertEquals(TaskStatus.done, reloaded.status);
        assertEquals(3, reloaded.pointsAwarded);
    }

    @Transactional
    Task reload(UUID taskId) {
        return Task.findById(taskId);
    }

    @Transactional
    long countTasks(UUID templateId, TaskStatus status) {
        return Task.count("templateId = ?1 and status = ?2", templateId, status);
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
