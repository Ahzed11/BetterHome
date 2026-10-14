package com.betterhome.tasks;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.tasks.domain.AssignmentMode;
import com.betterhome.tasks.domain.NotificationOutbox;
import com.betterhome.tasks.domain.Rotation;
import com.betterhome.tasks.domain.Task;
import com.betterhome.tasks.domain.TaskRecurrence;
import com.betterhome.tasks.domain.TaskStatus;
import com.betterhome.tasks.domain.TaskTemplate;
import com.betterhome.tasks.membership.InMemoryMembershipGateway;
import com.betterhome.tasks.membership.MembershipGateway.HouseholdSettings;
import com.betterhome.tasks.membership.MembershipGateway.MemberView;
import com.betterhome.tasks.service.RecurrenceService;
import com.betterhome.tasks.service.RecurrenceSpawnService;
import com.betterhome.tasks.service.TemplateService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Several scheduler instances running at once never spawn an occurrence twice (spec 3.1). */
@QuarkusTest
class SpawnConcurrencyTest {

    private static final Instant NOW = Instant.parse("2026-10-14T10:00:00Z");
    private static final UUID HOUSEHOLD = UUID.fromString("c0c0c0c0-0000-0000-0000-000000000001");
    private static final UUID ADMIN_SUBJECT =
            UUID.fromString("c0111111-1111-1111-1111-111111111111");
    private static final UUID ADMIN_USER = UUID.fromString("c0aaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static final UUID MEMBER_USER = UUID.fromString("c0bbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");

    @Inject TemplateService templateService;
    @Inject RecurrenceService recurrenceService;
    @Inject RecurrenceSpawnService spawnService;
    @Inject InMemoryMembershipGateway membershipGateway;
    @Inject CurrentIdentityAssociation identityAssociation;
    @Inject TestClock clock;

    @BeforeEach
    void setUp() {
        clock.fixAt(NOW);
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            NotificationOutbox.deleteAll();
                            Task.deleteAll();
                            TaskRecurrence.deleteAll();
                            TaskTemplate.deleteAll();
                            Rotation.deleteAll();
                        });
        membershipGateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, ADMIN_SUBJECT, true, false, 1),
                        new MemberView(
                                MEMBER_USER,
                                UUID.fromString("c0222222-2222-2222-2222-222222222222"),
                                false,
                                false,
                                2)));
        membershipGateway.putSettings(
                HOUSEHOLD, new HouseholdSettings("UTC", 0, LocalTime.of(8, 0)));
    }

    @AfterEach
    void tearDown() {
        clock.useSystemTime();
    }

    @Test
    void fourSchedulersSpawnEveryDueOccurrenceExactlyOnce() throws Exception {
        int recurrences = 20;
        List<UUID> templates = new ArrayList<>();
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder()
                        .setPrincipal(() -> ADMIN_SUBJECT.toString())
                        .addRole("member")
                        .build());
        for (int i = 0; i < recurrences; i++) {
            TaskTemplate template =
                    templateService.create(HOUSEHOLD, "Chore " + i, null, "", 2, 1, 60);
            templates.add(template.id);
            // Started a minute ago: exactly one occurrence is due now, the next is tomorrow.
            recurrenceService.upsert(
                    HOUSEHOLD,
                    template.id,
                    "FREQ=DAILY",
                    AssignmentMode.round_robin,
                    null,
                    NOW.minusSeconds(60),
                    null);
        }

        ExecutorService pool = Executors.newFixedThreadPool(4);
        int spawned = 0;
        try {
            List<Future<Integer>> runs = new ArrayList<>();
            for (int i = 0; i < 4; i++) {
                runs.add(pool.submit(() -> spawnService.claimAndSpawnDue(100)));
            }
            for (Future<Integer> run : runs) {
                spawned += run.get(60, TimeUnit.SECONDS);
            }
        } finally {
            pool.shutdownNow();
        }

        assertEquals(recurrences, spawned, "every occurrence was taken by exactly one scheduler");
        for (UUID template : templates) {
            long open =
                    QuarkusTransaction.requiringNew()
                            .call(
                                    () ->
                                            Task.count(
                                                    "templateId = ?1 and status = ?2",
                                                    template,
                                                    TaskStatus.open));
            long all =
                    QuarkusTransaction.requiringNew()
                            .call(() -> Task.count("templateId = ?1", template));
            assertEquals(1, open, "one open task for " + template);
            assertEquals(1, all, "and nothing else: no duplicate, nothing superseded");
        }
        long notices =
                QuarkusTransaction.requiringNew()
                        .call(() -> NotificationOutbox.count("type = ?1", "task_assigned"));
        assertEquals(recurrences, notices, "one notification per spawned task");
        assertEquals(
                0,
                QuarkusTransaction.requiringNew()
                        .call(
                                () ->
                                        TaskRecurrence.count(
                                                "nextRunAt is not null and nextRunAt <= ?1", NOW)),
                "every recurrence moved on to its next occurrence");
    }
}
