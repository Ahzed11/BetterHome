package com.betterhome.tasks;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import com.betterhome.tasks.service.TaskService;
import com.betterhome.tasks.service.TemplateService;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class InternalAwayDismissalTest {

    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("33333333-3333-3333-3333-333333333333");
    private static final UUID ADMIN_USER = UUID.fromString("cccccccc-cccc-cccc-cccc-cccccccccccc");
    private static final UUID MEMBER_USER = UUID.fromString("dddddddd-dddd-dddd-dddd-dddddddddddd");

    @Inject TemplateService templateService;
    @Inject TaskService taskService;
    @Inject InMemoryMembershipGateway membershipGateway;
    @Inject CurrentIdentityAssociation identityAssociation;

    private UUID household;
    private Task open;

    @BeforeEach
    void seed() {
        household = UUID.randomUUID();
        setMemberAway(false);
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder()
                        .setPrincipal(() -> ADMIN_SUBJECT.toString())
                        .addRole("member")
                        .build());
        TaskTemplate template = templateService.create(household, "Dishes", null, "", 3, 1, 30);
        open = taskService.createOpen(household, template.id, MEMBER_USER, null);
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder().setAnonymous(true).build());
        setMemberAway(true);
    }

    private void setMemberAway(boolean away) {
        membershipGateway.replaceHouseholdMembers(
                household,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(MEMBER_USER, UUID.randomUUID(), false, away, 2)));
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void serviceAccountDismissesOpenTasksRecordedAgainstTheAdminWhoSetAway() {
        given().when()
                .post(url() + "?dismissedBy=" + ADMIN_USER)
                .then()
                .statusCode(200)
                .body("dismissed", is(1));

        Task dismissed = Task.findInHousehold(household, open.id).orElseThrow();
        assertEquals(TaskStatus.dismissed, dismissed.status);
        assertEquals(DismissalReason.assignee_away, dismissed.dismissalReason);
        assertEquals(ADMIN_USER, dismissed.dismissedBy);
    }

    @Test
    @TestSecurity(
            user = "someone",
            roles = {"admin", "member"})
    void householdUsersAreRefusedAndNothingChanges() {
        given().when().post(url() + "?dismissedBy=" + ADMIN_USER).then().statusCode(403);

        assertEquals(
                TaskStatus.open, Task.findInHousehold(household, open.id).orElseThrow().status);
    }

    @Test
    void anonymousCallersAreRefused() {
        given().when().post(url() + "?dismissedBy=" + ADMIN_USER).then().statusCode(401);
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void dismissedByIsRequired() {
        given().when().post(url()).then().statusCode(400);
    }

    private String url() {
        return "/v1/internal/households/" + household + "/tasks/dismiss-away/" + MEMBER_USER;
    }
}
