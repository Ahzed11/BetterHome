package com.betterhome.tasks;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.betterhome.common.openapi.ContractValidation;
import com.betterhome.tasks.domain.AssignmentMode;
import com.betterhome.tasks.domain.DismissalReason;
import com.betterhome.tasks.domain.NotificationOutbox;
import com.betterhome.tasks.domain.Rotation;
import com.betterhome.tasks.domain.SystemActors;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskException;
import com.betterhome.tasks.domain.TaskOrigin;
import com.betterhome.tasks.domain.TaskRecurrence;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.service.AnonymizationService;
import com.betterhome.tasks.service.AnonymizationService.Result;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Account deletion in tasks-service: the service itself, then the internal endpoint. */
@QuarkusTest
class AnonymizeUserTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");
    private static final UUID ANONYMOUS = new UUID(0L, 0L);

    @Inject AnonymizationService service;
    @Inject EntityManager entityManager;

    private UUID leaver;
    private UUID other;
    private UUID household;
    private UUID rotation;
    private UUID template;
    private UUID recurrence;
    private UUID openOfLeaver;
    private UUID doneByLeaver;
    private UUID dismissedByLeaver;
    private UUID openOfOther;
    private UUID outboxOfLeaver;
    private UUID outboxOfOther;

    @BeforeEach
    void seed() {
        leaver = UUID.randomUUID();
        other = UUID.randomUUID();
        household = UUID.randomUUID();
        rotation = UUID.randomUUID();
        template = UUID.randomUUID();
        recurrence = UUID.randomUUID();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            Rotation r = new Rotation();
                            r.id = rotation;
                            r.householdId = household;
                            r.lastAssignedUserId = leaver;
                            r.createdAt = T0;
                            r.persist();
                            TaskTemplate t = new TaskTemplate();
                            t.id = template;
                            t.householdId = household;
                            t.title = "Dishes";
                            t.description = "";
                            t.points = 3;
                            t.latePoints = 1;
                            t.defaultDueOffsetMinutes = 60;
                            t.rotationId = rotation;
                            t.createdBy = leaver;
                            t.createdAt = T0;
                            t.updatedAt = T0;
                            t.persist();
                            TaskRecurrence rec = new TaskRecurrence();
                            rec.id = recurrence;
                            rec.householdId = household;
                            rec.templateId = template;
                            rec.rotationId = rotation;
                            rec.rrule = "FREQ=DAILY";
                            rec.assignmentMode = AssignmentMode.fixed;
                            rec.fixedAssigneeId = leaver;
                            rec.timezone = "UTC";
                            rec.startsAt = T0;
                            rec.createdAt = T0;
                            rec.updatedAt = T0;
                            rec.persist();
                            openOfLeaver = task(TaskStatus.open, leaver, null, null).id;
                            openOfOther = task(TaskStatus.open, other, null, null).id;
                            doneByLeaver = task(TaskStatus.done, other, leaver, null).id;
                            dismissedByLeaver = task(TaskStatus.dismissed, other, null, leaver).id;
                            outboxOfLeaver = outbox(leaver).id;
                            outboxOfOther = outbox(other).id;
                        });
    }

    private Task task(TaskStatus status, UUID assignee, UUID completer, UUID dismissedBy) {
        Task task = new Task();
        task.id = UUID.randomUUID();
        task.householdId = household;
        task.templateId = template;
        task.origin = TaskOrigin.manual;
        task.title = "Dishes";
        task.description = "";
        task.points = 3;
        task.latePoints = 1;
        task.status = status;
        task.assigneeId = assignee;
        task.completerId = completer;
        task.dismissedBy = dismissedBy;
        if (status == TaskStatus.dismissed) {
            task.dismissalReason = DismissalReason.manual;
        }
        if (status == TaskStatus.done) {
            task.completedAt = T0;
            task.pointsAwarded = 3;
        }
        task.createdAt = T0;
        task.updatedAt = T0;
        task.persist();
        return task;
    }

    private NotificationOutbox outbox(UUID user) {
        NotificationOutbox row = new NotificationOutbox();
        row.id = UUID.randomUUID();
        row.householdId = household;
        row.userId = user;
        row.type = "task_assigned";
        row.payloadJson = "{}";
        row.createdAt = T0;
        row.availableAt = T0;
        row.persist();
        return row;
    }

    private <T> T reload(Class<T> type, UUID id) {
        return QuarkusTransaction.requiringNew().call(() -> entityManager.find(type, id));
    }

    @Test
    void everyColumnHoldingTheUserIsReplacedAndNothingElseChanges() {
        Result result = service.anonymize(leaver);

        assertEquals(new Result(1, 1, 1, 1, 1, 1, 1, 1L), result);

        Task dismissedOpen = reload(Task.class, openOfLeaver);
        assertEquals(TaskStatus.dismissed, dismissedOpen.status);
        assertEquals(DismissalReason.assignee_away, dismissedOpen.dismissalReason);
        assertEquals(SystemActors.AUTOMATION, dismissedOpen.dismissedBy);
        assertEquals(ANONYMOUS, dismissedOpen.assigneeId);

        assertEquals(TaskStatus.open, reload(Task.class, openOfOther).status);
        assertEquals(other, reload(Task.class, openOfOther).assigneeId);
        Task done = reload(Task.class, doneByLeaver);
        assertEquals(ANONYMOUS, done.completerId);
        assertEquals(other, done.assigneeId);
        assertEquals(T0, done.completedAt);
        Task dismissed = reload(Task.class, dismissedByLeaver);
        assertEquals(ANONYMOUS, dismissed.dismissedBy);
        assertEquals(DismissalReason.manual, dismissed.dismissalReason);

        assertEquals(ANONYMOUS, reload(TaskTemplate.class, template).createdBy);
        assertEquals(ANONYMOUS, reload(TaskRecurrence.class, recurrence).fixedAssigneeId);
        assertEquals(ANONYMOUS, reload(Rotation.class, rotation).lastAssignedUserId);
        assertNull(reload(NotificationOutbox.class, outboxOfLeaver));
        assertEquals(other, reload(NotificationOutbox.class, outboxOfOther).userId);
    }

    @Test
    void doingItAgainChangesNothing() {
        service.anonymize(leaver);

        assertEquals(new Result(0, 0, 0, 0, 0, 0, 0, 0L), service.anonymize(leaver));
    }

    @Test
    void aUserWithNoHistoryHereChangesNothing() {
        assertEquals(new Result(0, 0, 0, 0, 0, 0, 0, 0L), service.anonymize(UUID.randomUUID()));
        assertEquals(TaskStatus.open, reload(Task.class, openOfLeaver).status);
    }

    @Test
    void theAnonymousIdItselfIsRefused() {
        assertThrows(TaskException.BadRequest.class, () -> service.anonymize(ANONYMOUS));
    }

    private String url(UUID user) {
        return "/v1/internal/users/" + user + "/anonymize";
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void theServiceRoleAnonymizesOverHttp() {
        given().filter(ContractValidation.validRequests("tasks"))
                .post(url(leaver))
                .then()
                .statusCode(200)
                .body("openTasksDismissed", is(1))
                .body("tasksAssigned", is(1))
                .body("tasksCompleted", is(1))
                .body("tasksDismissed", is(1))
                .body("templatesCreated", is(1))
                .body("recurrencesFixed", is(1))
                .body("rotationCursors", is(1))
                .body("queuedNotificationsDropped", is(1));

        assertEquals(ANONYMOUS, reload(TaskTemplate.class, template).createdBy);
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void repeatingOverHttpAnswersOkWithZeroes() {
        given().post(url(leaver)).then().statusCode(200);

        given().filter(ContractValidation.validRequests("tasks"))
                .post(url(leaver))
                .then()
                .statusCode(200)
                .body("openTasksDismissed", is(0))
                .body("tasksAssigned", is(0))
                .body("queuedNotificationsDropped", is(0));
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void theAnonymousIdIsRefusedOverHttp() {
        given().post(url(ANONYMOUS)).then().statusCode(400);
    }

    @Test
    @TestSecurity(
            user = "someone",
            roles = {"admin", "member"})
    void householdUsersAreRefusedAndNothingChanges() {
        given().post(url(leaver)).then().statusCode(403);

        assertEquals(leaver, reload(TaskTemplate.class, template).createdBy);
    }

    @Test
    void anonymousCallersAreRefused() {
        given().post(url(leaver)).then().statusCode(401);
    }
}
