package com.betterhome.notifications.service;

import com.betterhome.common.PushSender;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import jakarta.inject.Inject;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.logging.Logger;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * Delivers pushes through a Gotify server (ADR 0027): {@code POST /message} with the recipient's
 * own application token. Without {@code betterhome.gotify.url} nothing is sent. A failure is logged
 * without the token, the title or the body and never reaches the caller: the notification is
 * already stored. A refused token (401, 403, 404) means the target is dead and it is removed.
 */
@Alternative
@Priority(1)
@ApplicationScoped
public class GotifyPushSender implements PushSender {

    static final int PRIORITY = 5;
    static final String EXTRAS_KEY = "betterhome::push";
    private static final Logger LOG = Logger.getLogger(GotifyPushSender.class.getName());
    private static final Duration TIMEOUT = Duration.ofSeconds(5);
    private static final TypeReference<Map<String, String>> STRING_MAP = new TypeReference<>() {};

    private final Optional<String> baseUrl;
    private final PushTargetService targets;
    private final ObjectMapper json;
    private final HttpClient http;

    @Inject
    public GotifyPushSender(
            @ConfigProperty(name = "betterhome.gotify.url") Optional<String> baseUrl,
            PushTargetService targets,
            ObjectMapper json) {
        this.baseUrl = baseUrl.filter(url -> !url.isBlank());
        this.targets = targets;
        this.json = json;
        this.http = HttpClient.newBuilder().connectTimeout(TIMEOUT).build();
    }

    @Override
    public void send(PushMessage message) {
        if (baseUrl.isEmpty()) {
            return;
        }
        UUID userId = UUID.fromString(message.userId());
        Optional<String> token = targets.tokenOf(userId);
        if (token.isEmpty()) {
            return;
        }
        try {
            HttpResponse<Void> response =
                    http.send(
                            request(baseUrl.get(), token.get(), message),
                            HttpResponse.BodyHandlers.discarding());
            handle(response.statusCode(), userId, token.get(), message.type());
        } catch (IOException e) {
            LOG.warning("Gotify unreachable, push dropped: type=" + message.type());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            LOG.warning("Interrupted while sending a push, push dropped: type=" + message.type());
        }
    }

    private void handle(int status, UUID userId, String token, String type) {
        if (status >= 200 && status < 300) {
            return;
        }
        if (status == 401 || status == 403 || status == 404) {
            boolean removed = targets.removeRefused(userId, token);
            LOG.warning(
                    "Gotify refused the push target (status "
                            + status
                            + "), removed="
                            + removed
                            + ": user="
                            + userId);
        } else {
            LOG.warning("Gotify answered status " + status + ", push dropped: type=" + type);
        }
    }

    /** The smallest message Gotify accepts: the rendered text, and the IDs the app opens. */
    private HttpRequest request(String base, String token, PushMessage message) {
        ObjectNode body = json.createObjectNode();
        body.put("title", message.title());
        body.put("message", message.body());
        body.put("priority", PRIORITY);
        ObjectNode extras = body.putObject("extras").putObject(EXTRAS_KEY);
        payload(message).forEach(extras::put);
        extras.put("type", message.type());
        try {
            return HttpRequest.newBuilder(URI.create(base.replaceAll("/+$", "") + "/message"))
                    .timeout(TIMEOUT)
                    .header("Content-Type", "application/json")
                    .header("X-Gotify-Key", token)
                    .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)))
                    .build();
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("A push body cannot be serialized", e);
        }
    }

    private Map<String, String> payload(PushMessage message) {
        try {
            return json.readValue(message.payloadJson(), STRING_MAP);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("A push payload is a map of strings", e);
        }
    }
}
