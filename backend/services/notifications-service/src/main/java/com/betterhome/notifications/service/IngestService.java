package com.betterhome.notifications.service;

import com.betterhome.common.Clock;
import com.betterhome.common.PushSender;
import com.betterhome.notifications.directory.UsersGateway;
import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationException;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.service.MessageRenderer.Message;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Accepts events from other services (ADR 0017): checks them, applies the recipient's preferences,
 * renders the text in the recipient's language, stores one row per channel and only then hands the
 * push row to the {@link PushSender}.
 */
@ApplicationScoped
public class IngestService {

    static final int MAX_PAYLOAD_ENTRIES = 10;
    static final int MAX_PAYLOAD_VALUE_LENGTH = 200;

    private static final String INSERT =
            "INSERT INTO notification (id, household_id, user_id, type, channel, title, body,"
                    + " payload, idempotency_key, created_at)"
                    + " VALUES (:id, :household, :user, :type, :channel, :title, :body,"
                    + " CAST(:payload AS jsonb), :key, :createdAt)"
                    + " ON CONFLICT (idempotency_key, channel) DO NOTHING";

    /** What a producer sends. */
    public record Event(
            String idempotencyKey,
            UUID householdId,
            UUID userId,
            String type,
            Map<String, String> payload,
            String localeHint) {}

    /** What became of an event. */
    public enum Outcome {
        created,
        duplicate,
        suppressed
    }

    /**
     * The outcome and, unless suppressed, the inbox notification (or the push one if only that).
     */
    public record Result(Outcome outcome, Optional<Notification> notification) {}

    private final PreferenceService preferences;
    private final UsersGateway users;
    private final MessageRenderer renderer;
    private final PushSender pushSender;
    private final Clock clock;
    private final EntityManager entityManager;
    private final ObjectMapper json;

    @Inject
    public IngestService(
            PreferenceService preferences,
            UsersGateway users,
            MessageRenderer renderer,
            PushSender pushSender,
            Clock clock,
            EntityManager entityManager,
            ObjectMapper json) {
        this.preferences = preferences;
        this.users = users;
        this.renderer = renderer;
        this.pushSender = pushSender;
        this.clock = clock;
        this.entityManager = entityManager;
        this.json = json;
    }

    public Result ingest(Event event) {
        NotificationType type =
                NotificationType.parse(event.type())
                        .orElseThrow(
                                () ->
                                        new NotificationException.BadRequest(
                                                "Unknown notification type"));
        Map<String, String> payload = validPayload(type, event.payload());

        List<Channel> wanted = preferences.enabledChannels(event.userId(), type);
        if (wanted.isEmpty()) {
            return new Result(Outcome.suppressed, Optional.empty());
        }
        List<Channel> missing = missingChannels(event.idempotencyKey(), wanted);
        if (missing.isEmpty()) {
            return new Result(Outcome.duplicate, representative(event.idempotencyKey()));
        }

        Message message =
                renderer.render(type, payload, languageOf(event.userId(), event.localeHint()));
        List<Notification> stored =
                QuarkusTransaction.requiringNew()
                        .call(() -> store(event, type, payload, message, missing));
        for (Notification row : stored) {
            if (row.channel == Channel.push) {
                pushSender.send(
                        new PushSender.PushMessage(
                                row.userId.toString(),
                                row.type.name(),
                                row.title,
                                row.body,
                                payloadJson(row.payload)));
            }
        }
        Outcome outcome = stored.isEmpty() ? Outcome.duplicate : Outcome.created;
        return new Result(outcome, representative(event.idempotencyKey()));
    }

    private static Map<String, String> validPayload(
            NotificationType type, Map<String, String> payload) {
        Map<String, String> safe = payload == null ? Map.of() : payload;
        if (safe.size() > MAX_PAYLOAD_ENTRIES) {
            throw new NotificationException.BadRequest("Payload has too many entries");
        }
        for (Map.Entry<String, String> entry : safe.entrySet()) {
            if (entry.getValue() == null || entry.getValue().length() > MAX_PAYLOAD_VALUE_LENGTH) {
                throw new NotificationException.BadRequest(
                        "Payload values must be short text: " + entry.getKey());
            }
        }
        for (String key : type.requiredPayloadKeys()) {
            String value = safe.get(key);
            if (value == null || value.isBlank()) {
                throw new NotificationException.BadRequest("Payload is missing " + key);
            }
        }
        return safe;
    }

    private List<Channel> missingChannels(String key, List<Channel> wanted) {
        List<Channel> present =
                QuarkusTransaction.requiringNew()
                        .call(
                                () ->
                                        Notification.findByKey(key).stream()
                                                .map(n -> n.channel)
                                                .toList());
        return wanted.stream().filter(channel -> !present.contains(channel)).toList();
    }

    private Optional<Notification> representative(String key) {
        List<Notification> rows =
                QuarkusTransaction.requiringNew().call(() -> Notification.findByKey(key));
        return rows.stream()
                .filter(row -> row.channel == Channel.in_app)
                .findFirst()
                .or(() -> rows.stream().findFirst());
    }

    /** The households profile decides; the hint only helps when the user is unknown there. */
    private String languageOf(UUID userId, String localeHint) {
        return users.findById(userId)
                .map(UsersGateway.UserView::language)
                .orElseGet(
                        () ->
                                MessageRenderer.parseLanguage(localeHint)
                                        .orElse(MessageRenderer.DEFAULT_LANGUAGE));
    }

    private List<Notification> store(
            Event event,
            NotificationType type,
            Map<String, String> payload,
            Message message,
            List<Channel> channels) {
        List<Notification> inserted = new ArrayList<>();
        for (Channel channel : channels) {
            UUID id = UUID.randomUUID();
            int count =
                    entityManager
                            .createNativeQuery(INSERT)
                            .setParameter("id", id)
                            .setParameter("household", event.householdId())
                            .setParameter("user", event.userId())
                            .setParameter("type", type.name())
                            .setParameter("channel", channel.name())
                            .setParameter("title", message.title())
                            .setParameter("body", message.body())
                            .setParameter("payload", payloadJson(payload))
                            .setParameter("key", event.idempotencyKey())
                            .setParameter("createdAt", clock.now())
                            .executeUpdate();
            if (count == 1) {
                inserted.add(Notification.findById(id));
            }
        }
        return inserted;
    }

    private String payloadJson(Map<String, String> payload) {
        try {
            return json.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Payload of strings cannot be serialized", e);
        }
    }
}
