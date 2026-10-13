package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import com.betterhome.tasks.service.TaskService;
import com.betterhome.tasks.service.TemplateService;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TaskPhase2Test {

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

    @Inject CurrentIdentityAssociation identityAssociation;

    @BeforeEach
    void seedMembers() {
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, false, 2)));
    }

    @Test
    void templateQuickLogCompleteDismissAndReassign() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                templateService.create(
                                        HOUSEHOLD, "Bins", "🗑️", "Take out bins", 5, 2, 60));

        Task manual = asUser(MEMBER_SUBJECT, () -> taskService.quickLog(HOUSEHOLD, template.id));
        assertEquals(TaskStatus.done, manual.status);
        assertEquals(TaskOrigin.manual, manual.origin);
        assertEquals(5, manual.pointsAwarded);
        assertNull(manual.dueAt);
        assertEquals(MEMBER_USER, manual.assigneeId);

        Task open =
                asUser(
                        ADMIN_SUBJECT,
                        () ->
                                taskService.createOpen(
                                        HOUSEHOLD,
                                        template.id,
                                        MEMBER_USER,
                                        Instant.parse("2026-01-01T12:00:00Z")));
        assertEquals(TaskStatus.open, open.status);

        Task late = asUser(MEMBER_SUBJECT, () -> taskService.complete(HOUSEHOLD, open.id));
        // system clock is "now" which is after 2026-01-01 in real time → late
        assertEquals(TaskStatus.done, late.status);
        assertEquals(2, late.pointsAwarded);
        assertEquals(MEMBER_USER, late.completerId);

        Task open2 =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.createOpen(HOUSEHOLD, template.id, ADMIN_USER, null));
        Task dismissed = asUser(ADMIN_SUBJECT, () -> taskService.dismiss(HOUSEHOLD, open2.id));
        assertEquals(TaskStatus.dismissed, dismissed.status);

        Task open3 =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.createOpen(HOUSEHOLD, template.id, ADMIN_USER, null));
        Task reassigned = asUser(ADMIN_SUBJECT, () -> taskService.reassign(HOUSEHOLD, open3.id));
        assertEquals(MEMBER_USER, reassigned.assigneeId);

        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.Forbidden.class,
                                () ->
                                        templateService.create(
                                                HOUSEHOLD, "Nope", null, "", 1, 0, 10)));
    }

    @Test
    void reassignAwayMovesOpenTasks() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Kitchen", null, "", 3, 1, 30));
        Task open =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.createOpen(HOUSEHOLD, template.id, MEMBER_USER, null));

        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, true, 2)));

        int count =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.reassignOpenTasksForAwayMember(HOUSEHOLD, MEMBER_USER));
        assertEquals(1, count);
        Task updated = Task.findInHousehold(HOUSEHOLD, open.id).orElseThrow();
        assertEquals(ADMIN_USER, updated.assigneeId);
    }

    @Test
    void archiveStopsNewUses() {
        TaskTemplate template =
                asUser(
                        ADMIN_SUBJECT,
                        () -> templateService.create(HOUSEHOLD, "Old", null, "", 1, 0, 10));
        asUser(ADMIN_SUBJECT, () -> templateService.archive(HOUSEHOLD, template.id));
        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.NotFound.class,
                                () -> taskService.quickLog(HOUSEHOLD, template.id)));
        assertTrue(
                asUser(MEMBER_SUBJECT, () -> templateService.list(HOUSEHOLD)).stream()
                        .noneMatch(t -> t.id.equals(template.id)));
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
