package com.betterhome.notifications.directory;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Local stand-in for Keycloak's token endpoint and the households-service user endpoints. Answers
 * use the shapes documented in {@code documentation/api/households-openapi.yaml}.
 */
public class FakeHouseholdsServer implements QuarkusTestResourceLifecycleManager {

    public static final String FRENCH_USER = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
    public static final String FRENCH_SUBJECT = "11111111-1111-1111-1111-111111111111";
    public static final String TOKEN = "notifications-service-account-token";

    /** Authorization headers received on households calls, in order. */
    public static final List<String> AUTHORIZATIONS = new CopyOnWriteArrayList<>();

    /** HTTP status to answer with; {@code -1} drops the connection without any answer. */
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
        server.createContext("/v1/internal/users/", this::users);
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
        respond(
                exchange,
                200,
                "{\"access_token\":\""
                        + TOKEN
                        + "\",\"token_type\":\"Bearer\",\"expires_in\":300}");
    }

    private void users(HttpExchange exchange) throws IOException {
        AUTHORIZATIONS.add(exchange.getRequestHeaders().getFirst("Authorization"));
        String path = exchange.getRequestURI().getPath();
        if (householdsStatus == -1) {
            exchange.close();
        } else if (householdsStatus != 200) {
            respond(exchange, householdsStatus, "{}");
        } else if (path.endsWith("/" + FRENCH_USER) || path.endsWith("/" + FRENCH_SUBJECT)) {
            respond(
                    exchange,
                    200,
                    "{\"userId\":\""
                            + FRENCH_USER
                            + "\",\"authSubject\":\""
                            + FRENCH_SUBJECT
                            + "\",\"language\":\"fr\"}");
        } else {
            respond(exchange, 404, "{\"code\":\"not_found\"}");
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
