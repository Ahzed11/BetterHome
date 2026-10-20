package com.betterhome.households.erasure;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Local stand-in for Keycloak (token endpoint and the Admin API user deletion) and for the
 * anonymize endpoints of the four services, each under its own prefix. Request shapes follow {@code
 * documentation/api/*-openapi.yaml} and the Keycloak Admin REST API.
 */
public class FakeDeletionTargetsServer implements QuarkusTestResourceLifecycleManager {

    public static final String TOKEN = "households-service-account-token";

    /** A received call; {@code target} is the prefix: tasks, scoring, lists, notifications, kc. */
    public record Call(String target, String method, String path, String authorization) {}

    public static final List<Call> CALLS = new CopyOnWriteArrayList<>();

    /** HTTP status to answer with per target; {@code -1} drops the connection. */
    public static final Map<String, Integer> STATUS = new ConcurrentHashMap<>();

    private HttpServer server;

    public static void reset() {
        CALLS.clear();
        STATUS.clear();
    }

    @Override
    public Map<String, String> start() {
        try {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot start fake deletion targets server", e);
        }
        server.createContext(
                "/realms/test/protocol/openid-connect/token",
                exchange ->
                        respond(
                                exchange,
                                200,
                                "{\"access_token\":\""
                                        + TOKEN
                                        + "\",\"token_type\":\"Bearer\",\"expires_in\":300}"));
        for (String target : List.of("tasks", "scoring", "lists", "notifications", "kc")) {
            server.createContext("/" + target, exchange -> handle(target, exchange));
        }
        server.start();
        String base = "http://127.0.0.1:" + server.getAddress().getPort();
        return Map.of(
                "quarkus.oidc-client.auth-server-url", base + "/realms/test",
                "quarkus.rest-client.tasks.url", base + "/tasks",
                "quarkus.rest-client.scoring.url", base + "/scoring",
                "quarkus.rest-client.lists.url", base + "/lists",
                "quarkus.rest-client.notifications.url", base + "/notifications",
                "quarkus.rest-client.keycloak-admin.url", base + "/kc");
    }

    @Override
    public void stop() {
        server.stop(0);
    }

    private void handle(String target, HttpExchange exchange) throws IOException {
        exchange.getRequestBody().readAllBytes();
        String path = exchange.getRequestURI().getPath().substring(target.length() + 1);
        CALLS.add(
                new Call(
                        target,
                        exchange.getRequestMethod(),
                        path,
                        exchange.getRequestHeaders().getFirst("Authorization")));
        int status = STATUS.getOrDefault(target, "kc".equals(target) ? 204 : 200);
        if (status == -1) {
            exchange.close();
            return;
        }
        respond(exchange, status, status == 200 ? "{}" : "");
    }

    private static void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length == 0 ? -1 : bytes.length);
        if (bytes.length > 0) {
            exchange.getResponseBody().write(bytes);
        }
        exchange.close();
    }
}
