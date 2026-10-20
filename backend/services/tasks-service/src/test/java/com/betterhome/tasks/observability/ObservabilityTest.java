package com.betterhome.tasks.observability;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.tasks.membership.FakeHouseholdsServer;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import io.quarkus.test.security.TestSecurity;
import io.restassured.RestAssured;
import io.restassured.response.Response;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Request ids and trace ids in the logs, the same ids on outgoing REST calls, and no credentials or
 * personal data in the logs. The JSON layout of production is switched on and written to a file so
 * the assertions read exactly what an operator would read.
 */
@QuarkusTest
@TestProfile(ObservabilityTest.JsonLogs.class)
@QuarkusTestResource(value = FakeHouseholdsServer.class, restrictToAnnotatedClass = true)
class ObservabilityTest {

    static final String LOG_FILE = "target/observability-test.log";
    private static final String SUBJECT = "11111111-1111-1111-1111-111111111111";
    private static final ObjectMapper JSON = new ObjectMapper();

    public static class JsonLogs implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of(
                    "quarkus.log.file.enable", "true",
                    "quarkus.log.file.path", LOG_FILE,
                    "quarkus.log.file.json.enabled", "true",
                    "quarkus.log.console.json.enabled", "false");
        }
    }

    @BeforeEach
    void reset() {
        FakeHouseholdsServer.REQUEST_IDS.clear();
        FakeHouseholdsServer.TRACEPARENTS.clear();
        FakeHouseholdsServer.AUTHORIZATIONS.clear();
        // The probe is not part of the API contract the other tests validate against
        RestAssured.replaceFiltersWith(List.of());
    }

    @Test
    @TestSecurity(user = SUBJECT, roles = "admin")
    void aGeneratedRequestIdAndTheTraceIdAreInTheJsonLogAndTheAnswerHeader() throws IOException {
        Response response = given().get("/observability-probe");

        response.then().statusCode(200);
        String requestId = response.header("X-Request-ID");
        assertNotNull(requestId);
        assertEquals(requestId, response.jsonPath().getString("requestId"));
        String traceId = response.jsonPath().getString("traceId");
        assertNotEquals("00000000000000000000000000000000", traceId);

        JsonNode line = logLine("probe handled", requestId);
        assertEquals(requestId, line.path("mdc").path("requestId").asText());
        assertEquals(traceId, line.path("mdc").path("traceId").asText());
    }

    @Test
    @TestSecurity(user = SUBJECT, roles = "admin")
    void aWellFormedCallerRequestIdIsKeptAndAMalformedOneIsReplaced() {
        given().header("X-Request-ID", "client-req-12345")
                .get("/observability-probe")
                .then()
                .statusCode(200)
                .header("X-Request-ID", "client-req-12345");

        String forged = "bad id with spaces";
        Response replaced = given().header("X-Request-ID", forged).get("/observability-probe");
        assertNotEquals(forged, replaced.header("X-Request-ID"));
        assertEquals(36, replaced.header("X-Request-ID").length());
    }

    @Test
    @TestSecurity(user = SUBJECT, roles = "admin")
    void theRequestIdAndTheTraceContextReachTheServiceCalledOutward() {
        given().header("X-Request-ID", "client-req-67890").get("/observability-probe");

        assertEquals(List.of("client-req-67890"), FakeHouseholdsServer.REQUEST_IDS);
        assertNotNull(
                FakeHouseholdsServer.TRACEPARENTS.getFirst(),
                "OpenTelemetry must send traceparent on REST client calls");
    }

    @Test
    @TestSecurity(user = SUBJECT, roles = "admin")
    void theTraceIdOfTheRequestIsTheOneSentOutward() {
        Response response = given().get("/observability-probe");

        String traceId = response.jsonPath().getString("traceId");
        assertTrue(
                FakeHouseholdsServer.TRACEPARENTS.getFirst().contains("-" + traceId + "-"),
                "traceparent carries the trace id of the incoming request");
    }

    @Test
    @TestSecurity(user = SUBJECT, roles = "admin")
    void tokensAndEmailsSentByTheCallerNeverReachTheLogs() throws IOException {
        String bearer = "Bearer eyJhbGciOiJSUzI1NiJ9.secret-payload.secret-signature";
        String email = "jane.doe@example.com";

        given().header("Authorization", bearer)
                .header("X-Request-ID", "client-req-leak-1")
                .queryParam("email", email)
                .get("/observability-probe")
                .then()
                .statusCode(200);
        // an error path too: the request is refused, the log must still be clean
        given().header("Authorization", bearer)
                .queryParam("email", email)
                .get("/no-such-path")
                .then()
                .statusCode(404);

        String logs = Files.readString(Path.of(LOG_FILE));
        assertTrue(logs.contains("client-req-leak-1"), "the log file is the one being written");
        assertFalse(logs.contains("secret-payload"), "bearer token leaked into the logs");
        assertFalse(logs.contains("eyJhbGciOiJSUzI1NiJ9"), "bearer token leaked into the logs");
        assertFalse(logs.contains(FakeHouseholdsServer.TOKEN), "service token leaked");
        assertFalse(logs.contains(email), "email leaked into the logs");
    }

    private static JsonNode logLine(String message, String requestId) throws IOException {
        for (String line : Files.readAllLines(Path.of(LOG_FILE))) {
            if (line.startsWith("{")) {
                JsonNode node = JSON.readTree(line);
                if (node.path("message").asText().equals(message)
                        && node.path("mdc").path("requestId").asText().equals(requestId)) {
                    return node;
                }
            }
        }
        throw new AssertionError("no JSON log line '" + message + "' for request " + requestId);
    }
}
