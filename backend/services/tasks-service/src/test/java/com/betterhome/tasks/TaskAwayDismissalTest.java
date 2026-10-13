package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskException;
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
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TaskAwayDismissalTest {

    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID MEMBER_SUBJECT =
            UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID ADMIN_USER = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");

    private UUID household;
    private UUID otherHousehold;

    @Inject TemplateService templateService;
    @Inject TaskService taskService;
    @Inject InMemoryMembershipGateway membershipGateway;
    @Inject CurrentIdentityAssociation identityAssociation;

    @BeforeEach
    void seedMembers() {
        household = UUID.randomUUID();
        otherHousehold = UUID.randomUUID();
        setMemberAway(false);
    }

    private void setMemberAway(boolean away) {
        List<MemberView> members =
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, MEMBER_SUBJECT, false, away, 2));
        membershipGateway.replaceHouseholdMembers(household, members);
        membershipGateway.replaceHouseholdMembers(otherHousehold, members);
    }

    @Test
    void dismissesOnlyTheAwayMembersOpenTasksInThatHousehold() {
        TaskTemplate template = template(household);
        Task awayOpen = openTask(household, template, MEMBER_USER);
        Task awayDone = openTask(household, template, MEMBER_USER);
        asUser(ADMIN_SUBJECT, () -> taskService.complete(household, awayDone.id));
        Task adminOpen = openTask(household, template, ADMIN_USER);
        Task otherHouseholdOpen = openTask(otherHousehold, template(otherHousehold), MEMBER_USER);
        setMemberAway(true);

        int count =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.dismissOpenTasksForAwayMember(household, MEMBER_USER));

        assertEquals(1, count);
        Task dismissed = Task.findInHousehold(household, awayOpen.id).orElseThrow();
        assertEquals(TaskStatus.dismissed, dismissed.status);
        assertEquals(DismissalReason.assignee_away, dismissed.dismissalReason);
        assertEquals(ADMIN_USER, dismissed.dismissedBy);
        assertEquals(MEMBER_USER, dismissed.assigneeId);
        assertEquals(TaskStatus.done, reload(household, awayDone).status);
        assertEquals(TaskStatus.open, reload(household, adminOpen).status);
        assertEquals(TaskStatus.open, reload(otherHousehold, otherHouseholdOpen).status);
        assertNull(reload(household, adminOpen).dismissalReason);
    }

    @Test
    void noOpenTasksMeansNothingToDismiss() {
        setMemberAway(true);
        int count =
                asUser(
                        ADMIN_SUBJECT,
                        () -> taskService.dismissOpenTasksForAwayMember(household, MEMBER_USER));

        assertEquals(0, count);
    }

    @Test
    void onlyAdminsMayDismissForAnAwayMember() {
        Task open = openTask(household, template(household), MEMBER_USER);
        setMemberAway(true);

        asUser(
                MEMBER_SUBJECT,
                () ->
                        assertThrows(
                                TaskException.Forbidden.class,
                                () ->
                                        taskService.dismissOpenTasksForAwayMember(
                                                household, MEMBER_USER)));
        asUser(
                UUID.randomUUID(),
                () ->
                        assertThrows(
                                TaskException.Forbidden.class,
                                () ->
                                        taskService.dismissOpenTasksForAwayMember(
                                                household, MEMBER_USER)));

        assertEquals(TaskStatus.open, reload(household, open).status);
    }

    private TaskTemplate template(UUID householdId) {
        return asUser(
                ADMIN_SUBJECT,
                () -> templateService.create(householdId, "Kitchen", null, "", 3, 1, 30));
    }

    private Task openTask(UUID householdId, TaskTemplate template, UUID assignee) {
        return asUser(
                ADMIN_SUBJECT,
                () -> taskService.createOpen(householdId, template.id, assignee, null));
    }

    private static Task reload(UUID householdId, Task task) {
        return Task.findInHousehold(householdId, task.id).orElseThrow();
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
            identityAssociation.setIdentity(
                    previous != null
                            ? previous
                            : QuarkusSecurityIdentity.builder().setAnonymous(true).build());
        }
    }
}
