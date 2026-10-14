package com.betterhome.tasks.ledger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.tasks.domain.TaskException;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
@QuarkusTestResource(value = FakeScoringServer.class, restrictToAnnotatedClass = true)
class HttpPointsLedgerClientTest {

    private static final UUID HOUSEHOLD = UUID.randomUUID();
    private static final UUID ASSIGNEE = UUID.randomUUID();
    private static final UUID ADMIN = UUID.randomUUID();
    private static final UUID TASK = UUID.randomUUID();

    @Inject HttpPointsLedgerClient client;

    @BeforeEach
    @AfterEach
    void reset() {
        FakeScoringServer.CALLS.clear();
        FakeScoringServer.scoringStatus = 201;
    }

    @Test
    void awardPostsTheOnTimeReasonWithTheServiceToken() {
        client.award(HOUSEHOLD, ASSIGNEE, TASK, 1, 4, false);

        FakeScoringServer.Call call = FakeScoringServer.CALLS.get(0);
        assertEquals("/v1/households/" + HOUSEHOLD + "/points/award", call.path());
        assertEquals("Bearer " + FakeScoringServer.TOKEN, call.authorization());
        assertTrue(call.body().contains("\"userId\":\"" + ASSIGNEE + "\""));
        assertTrue(call.body().contains("\"taskId\":\"" + TASK + "\""));
        assertTrue(call.body().contains("\"completionNo\":1"));
        assertTrue(call.body().contains("\"points\":4"));
        assertTrue(call.body().contains("\"reason\":\"task_completed\""));
    }

    @Test
    void lateAwardUsesTheLateReason() {
        client.award(HOUSEHOLD, ASSIGNEE, TASK, 1, 2, true);

        assertTrue(
                FakeScoringServer.CALLS
                        .get(0)
                        .body()
                        .contains("\"reason\":\"task_completed_late\""));
    }

    @Test
    void reversePostsTheAdminAndTheResultingStatus() {
        client.reverse(HOUSEHOLD, TASK, ASSIGNEE, 4, ADMIN, "Logged by mistake", "reverted");

        FakeScoringServer.Call call = FakeScoringServer.CALLS.get(0);
        assertEquals("/v1/households/" + HOUSEHOLD + "/points/reverse", call.path());
        assertEquals("Bearer " + FakeScoringServer.TOKEN, call.authorization());
        assertTrue(call.body().contains("\"assigneeUserId\":\"" + ASSIGNEE + "\""));
        assertTrue(call.body().contains("\"adminUserId\":\"" + ADMIN + "\""));
        assertTrue(call.body().contains("\"reason\":\"Logged by mistake\""));
        assertTrue(call.body().contains("\"resultingStatus\":\"reverted\""));
    }

    @Test
    void anOutageIsReportedAsUnavailable() {
        FakeScoringServer.scoringStatus = 503;

        assertThrows(
                TaskException.ServiceUnavailable.class,
                () -> client.award(HOUSEHOLD, ASSIGNEE, TASK, 1, 4, false));
        assertThrows(
                TaskException.ServiceUnavailable.class,
                () -> client.reverse(HOUSEHOLD, TASK, ASSIGNEE, 4, ADMIN, "Oops", "reverted"));
    }

    @Test
    void aRejectedServiceTokenIsReportedAsUnavailable() {
        FakeScoringServer.scoringStatus = 403;

        assertThrows(
                TaskException.ServiceUnavailable.class,
                () -> client.award(HOUSEHOLD, ASSIGNEE, TASK, 1, 4, false));
    }

    @Test
    void aDroppedConnectionIsReportedAsUnavailable() {
        FakeScoringServer.scoringStatus = -1;

        assertThrows(
                TaskException.ServiceUnavailable.class,
                () -> client.award(HOUSEHOLD, ASSIGNEE, TASK, 1, 4, false));
    }

    @Test
    void aLedgerConflictIsReportedAsConflict() {
        FakeScoringServer.scoringStatus = 409;

        assertThrows(
                TaskException.Conflict.class,
                () -> client.reverse(HOUSEHOLD, TASK, ASSIGNEE, 4, ADMIN, "Twice", "reverted"));
    }
}
