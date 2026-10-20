package com.betterhome.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.PushSender.PushMessage;
import com.betterhome.notifications.FakeGotifyServer.Received;
import com.betterhome.notifications.domain.PushTarget;
import com.betterhome.notifications.service.GotifyPushSender;
import com.betterhome.notifications.service.PushTargetService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.logging.Handler;
import java.util.logging.LogRecord;
import java.util.logging.Logger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The Gotify sender against a fake of the Gotify HTTP boundary. */
@QuarkusTest
class GotifyPushSenderTest {

    private static final UUID ALICE = UUID.fromString("b1b1b1b1-0000-0000-0000-00000000000a");
    private static final String TOKEN = "SecretGotifyToken1";
    private static final String TITLE = "Dishes assigned to you";
    private static final String BODY = "Remember the dishes tonight";

    @Inject PushTargetService targets;
    @Inject ObjectMapper json;

    private FakeGotifyServer gotify;
    private GotifyPushSender sender;
    private final List<String> logged = new ArrayList<>();
    private final Handler capture =
            new Handler() {
                @Override
                public void publish(LogRecord record) {
                    logged.add(record.getMessage());
                }

                @Override
                public void flush() {}

                @Override
                public void close() {}
            };

    @BeforeEach
    void start() {
        QuarkusTransaction.requiringNew().run(() -> PushTarget.deleteAll());
        gotify = new FakeGotifyServer();
        sender = new GotifyPushSender(Optional.of(gotify.url()), targets, json);
        Logger.getLogger(GotifyPushSender.class.getName()).addHandler(capture);
    }

    @AfterEach
    void stop() {
        Logger.getLogger(GotifyPushSender.class.getName()).removeHandler(capture);
        gotify.close();
        QuarkusTransaction.requiringNew().run(() -> PushTarget.deleteAll());
    }

    private static PushMessage message() {
        return new PushMessage(
                ALICE.toString(),
                "task_assigned",
                TITLE,
                BODY,
                "{\"taskId\":\"t-1\",\"taskTitle\":\"Dishes\"}");
    }

    @Test
    void aPushIsPostedToGotifyWithTheUsersOwnToken() throws Exception {
        targets.register(ALICE, TOKEN);

        sender.send(message());

        assertEquals(1, gotify.received().size());
        Received request = gotify.received().get(0);
        assertEquals("POST", request.method());
        assertEquals("/message", request.path());
        assertEquals(TOKEN, request.key());
        JsonNode body = json.readTree(request.body());
        assertEquals(TITLE, body.get("title").asText());
        assertEquals(BODY, body.get("message").asText());
        assertEquals(5, body.get("priority").asInt());
        assertTrue(targets.tokenOf(ALICE).isPresent());
    }

    @Test
    void theBodyCarriesOnlyTheTextTheTypeAndThePayloadEntries() throws Exception {
        targets.register(ALICE, TOKEN);

        sender.send(message());

        JsonNode body = json.readTree(gotify.received().get(0).body());
        assertEquals(List.of("title", "message", "priority", "extras"), List.copyOf(names(body)));
        JsonNode extras = body.get("extras");
        assertEquals(List.of("betterhome::push"), List.copyOf(names(extras)));
        JsonNode push = extras.get("betterhome::push");
        assertEquals(List.of("taskId", "taskTitle", "type"), List.copyOf(names(push)));
        assertEquals("task_assigned", push.get("type").asText());
        assertFalse(gotify.received().get(0).body().contains(TOKEN));
        assertFalse(gotify.received().get(0).body().contains(ALICE.toString()));
    }

    @Test
    void aTrailingSlashOnTheBaseUrlIsHarmless() {
        targets.register(ALICE, TOKEN);

        new GotifyPushSender(Optional.of(gotify.url() + "/"), targets, json).send(message());

        assertEquals("/message", gotify.received().get(0).path());
    }

    @Test
    void aUserWithoutATargetGetsNoPush() {
        sender.send(message());

        assertTrue(gotify.received().isEmpty());
    }

    @Test
    void withoutAGotifyUrlNothingIsSent() {
        targets.register(ALICE, TOKEN);

        new GotifyPushSender(Optional.empty(), targets, json).send(message());
        new GotifyPushSender(Optional.of(" "), targets, json).send(message());

        assertTrue(gotify.received().isEmpty());
    }

    @Test
    void aRefusedTokenRemovesTheTarget() {
        for (int status : new int[] {401, 403, 404}) {
            targets.register(ALICE, TOKEN);
            gotify.answer(status);

            sender.send(message());

            assertTrue(targets.tokenOf(ALICE).isEmpty(), "status " + status);
        }
        assertEquals(3, gotify.received().size());
    }

    @Test
    void otherFailuresKeepTheTargetAndNeverReachTheCaller() {
        targets.register(ALICE, TOKEN);
        for (int status : new int[] {400, 429, 500, 503, -1}) {
            gotify.answer(status);

            sender.send(message());

            assertEquals(Optional.of(TOKEN), targets.tokenOf(ALICE), "status " + status);
        }
    }

    @Test
    void anUnreachableGotifyKeepsTheTargetAndNeverReachesTheCaller() {
        targets.register(ALICE, TOKEN);
        String closed = gotify.url();
        gotify.close();

        new GotifyPushSender(Optional.of(closed), targets, json).send(message());

        assertEquals(Optional.of(TOKEN), targets.tokenOf(ALICE));
    }

    @Test
    void logsNeverHoldTheTokenTheTitleOrTheBody() {
        targets.register(ALICE, TOKEN);
        for (int status : new int[] {401, 500, -1}) {
            targets.register(ALICE, TOKEN);
            gotify.answer(status);
            sender.send(message());
        }

        assertFalse(logged.isEmpty());
        for (String line : logged) {
            assertFalse(line.contains(TOKEN), line);
            assertFalse(line.contains(TITLE), line);
            assertFalse(line.contains(BODY), line);
            assertFalse(line.contains("Dishes"), line);
        }
    }

    private static List<String> names(JsonNode node) {
        List<String> names = new ArrayList<>();
        node.fieldNames().forEachRemaining(names::add);
        return names;
    }
}
