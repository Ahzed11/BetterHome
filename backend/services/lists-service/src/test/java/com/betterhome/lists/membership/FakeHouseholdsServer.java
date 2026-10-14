package com.betterhome.lists.membership;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Local stand-in for Keycloak's token endpoint and households-service internal endpoints. Answers
 * use the shapes documented in {@code documentation/api/households-internal-openapi.yaml}.
 */
public class FakeHouseholdsServer implements QuarkusTestResourceLifecycleManager {

    public static final String HOUSEHOLD = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    public static final String ADMIN_USER = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
    public static final String ADMIN_SUBJECT = "11111111-1111-1111-1111-111111111111";
    public static final String MEMBER_USER = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
    public static final String MEMBER_SUBJECT = "22222222-2222-2222-2222-222222222222";
    public static final String TOKEN = "service-account-token";

    /** Authorization headers received on households calls, in order. */
    public static final List<String> AUTHORIZATIONS = new CopyOnWriteArrayList<>();

    public static final AtomicInteger TOKEN_REQUESTS = new AtomicInteger();
    public static volatile int householdsStatus = 200;

    private HttpServer server;

    @Override
    public Map<String, String> start() {
        try {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot start fake households server", e);
        }
        server.createContext("/realms/test/protocol/openid-connect/token", this::token);
        server.createContext("/v1/internal/households/", this::households);
        server.start();
        String base = "http://127.0.0.1:" + server.getAddress().getPort();
        return Map.of(
                "quarkus.oidc-client.auth-server-url",
                base + "/realms/test",
                "quarkus.rest-client.households.url",
                base);
    }

    @Override
    public void stop() {
        server.stop(0);
    }

    private void token(HttpExchange exchange) throws IOException {
        TOKEN_REQUESTS.incrementAndGet();
        respond(
                exchange,
                200,
                "{\"access_token\":\""
                        + TOKEN
                        + "\",\"token_type\":\"Bearer\",\"expires_in\":300}");
    }

    private void households(HttpExchange exchange) throws IOException {
        AUTHORIZATIONS.add(exchange.getRequestHeaders().getFirst("Authorization"));
        if (householdsStatus != 200) {
            respond(exchange, householdsStatus, "{}");
            return;
        }
        String path = exchange.getRequestURI().getPath();
        if (!path.contains(HOUSEHOLD)) {
            respond(exchange, 404, "{\"code\":\"not_found\"}");
        } else if (path.endsWith("/members")) {
            respond(
                    exchange,
                    200,
                    "[{\"userId\":\""
                            + ADMIN_USER
                            + "\",\"authSubject\":\""
                            + ADMIN_SUBJECT
                            + "\",\"role\":\"admin\",\"away\":false,"
                            + "\"joinedAt\":\"2026-01-01T10:00:00Z\"},"
                            + "{\"userId\":\""
                            + MEMBER_USER
                            + "\",\"authSubject\":\""
                            + MEMBER_SUBJECT
                            + "\",\"role\":\"member\",\"away\":true,"
                            + "\"joinedAt\":\"2026-01-02T10:00:00Z\"}]");
        } else {
            respond(
                    exchange,
                    200,
                    "{\"timezone\":\"Europe/Paris\",\"reminderDaysBefore\":1,"
                            + "\"reminderTime\":\"08:30:00\"}");
        }
    }

    private static void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }
}
