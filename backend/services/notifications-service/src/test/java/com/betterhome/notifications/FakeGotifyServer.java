package com.betterhome.notifications;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * The Gotify HTTP boundary in tests: records every {@code POST /message} (the application token
 * header and the JSON body) and answers with a chosen status. {@code -1} drops the connection.
 */
public class FakeGotifyServer implements AutoCloseable {

    /** What Gotify received. */
    public record Received(String method, String path, String key, String body) {}

    private final List<Received> received = new CopyOnWriteArrayList<>();
    private final HttpServer server;
    private volatile int status = 200;

    public FakeGotifyServer() {
        try {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot start the fake Gotify server", e);
        }
        server.createContext("/", this::handle);
        server.start();
    }

    public String url() {
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }

    public List<Received> received() {
        return List.copyOf(received);
    }

    public void answer(int newStatus) {
        status = newStatus;
    }

    @Override
    public void close() {
        server.stop(0);
    }

    private void handle(HttpExchange exchange) throws IOException {
        String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        received.add(
                new Received(
                        exchange.getRequestMethod(),
                        exchange.getRequestURI().toString(),
                        exchange.getRequestHeaders().getFirst("X-Gotify-Key"),
                        body));
        int answer = status;
        if (answer == -1) {
            exchange.close();
            return;
        }
        byte[] bytes = "{}".getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(answer, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }
}
