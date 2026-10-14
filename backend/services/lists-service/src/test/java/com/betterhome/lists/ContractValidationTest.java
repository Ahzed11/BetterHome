package com.betterhome.lists;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.betterhome.common.openapi.ContractValidation;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.filter.Filter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Proves that response validation really fails: the real {@code /v1/meta} answer is checked against
 * deliberately tampered copies of the committed contract, each of which the answer must violate.
 */
@QuarkusTest
@TestSecurity(user = "11111111-1111-1111-1111-111111111111", roles = "member")
class ContractValidationTest {

    private static final ObjectMapper YAML = new ObjectMapper(new YAMLFactory());

    @TempDir Path tmp;

    @Test
    void theCommittedContractAcceptsTheRealAnswer() {
        callMeta(ContractValidation.of("lists"));
    }

    @Test
    void anUndocumentedFieldInTheAnswerFails() throws IOException {
        Path tampered = tamper(contract -> serviceInfoProperties(contract).remove("authSubject"));

        RuntimeException failure = failureOf(tampered);

        assertTrue(failure.getMessage().contains("authSubject"), failure.getMessage());
    }

    @Test
    void aWrongTypeInTheAnswerFails() throws IOException {
        Path tampered =
                tamper(
                        contract ->
                                ((ObjectNode) serviceInfoProperties(contract).get("now"))
                                        .put("type", "integer"));

        RuntimeException failure = failureOf(tampered);

        assertTrue(failure.getMessage().contains("now"), failure.getMessage());
    }

    @Test
    void anUndocumentedStatusCodeFails() throws IOException {
        Path tampered =
                tamper(
                        contract ->
                                ((ObjectNode) contract.at("/paths/~1v1~1meta/get/responses"))
                                        .remove("200"));

        RuntimeException failure = failureOf(tampered);

        assertTrue(failure.getMessage().contains("200"), failure.getMessage());
    }

    private RuntimeException failureOf(Path tampered) {
        return assertThrows(
                RuntimeException.class, () -> callMeta(ContractValidation.of(tampered)));
    }

    private static void callMeta(Filter filter) {
        given().filter(filter).when().get("/v1/meta").then().statusCode(200);
    }

    private static ObjectNode serviceInfoProperties(JsonNode contract) {
        return (ObjectNode) contract.at("/components/schemas/ServiceInfo/properties");
    }

    private Path tamper(Consumer<JsonNode> change) throws IOException {
        JsonNode contract =
                YAML.readTree(Files.readString(ContractValidation.committedContract("lists")));
        change.accept(contract);
        Path copy = tmp.resolve("tampered-openapi.yaml");
        Files.writeString(copy, YAML.writeValueAsString(contract));
        return copy;
    }
}
