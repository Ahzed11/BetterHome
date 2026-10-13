package com.betterhome.tasks.ledger;

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
 * Local stand-in for Keycloak's token endpoint and the ledger write endpoints of scoring-service.
 * Request and answer shapes follow {@code documentation/api/scoring-openapi.yaml}.
 */
public class FakeScoringServer implements QuarkusTestResourceLifecycleManager {

    public static final String TOKEN = "tasks-service-account-token";

    /** A received ledger call. */
    public record Call(String path, String authorization, String body) {}

    public static final List<Call> CALLS = new CopyOnWriteArrayList<>();

    /** HTTP status to answer with; {@code -1} drops the connection without any answer. */
    public static volatile int scoringStatus = 201;

    private HttpServer server;

    @Override
    public Map<String, String> start() {
        try {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot start fake scoring server", e);
        }
        server.createContext("/realms/test/protocol/openid-connect/token", this::token);
        server.createContext("/v1/households/", this::scoring);
        server.start();
        String base = "http://127.0.0.1:" + server.getAddress().getPort();
        return Map.of(
                "quarkus.oidc-client.auth-server-url",
                base + "/realms/test",
                "quarkus.rest-client.scoring.url",
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

    private void scoring(HttpExchange exchange) throws IOException {
        String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        CALLS.add(
                new Call(
                        exchange.getRequestURI().getPath(),
                        exchange.getRequestHeaders().getFirst("Authorization"),
                        body));
        if (scoringStatus == -1) {
            exchange.close();
            return;
        }
        respond(exchange, scoringStatus, "{}");
    }

    private static void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }
}
