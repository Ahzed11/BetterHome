package com.betterhome.common.openapi;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import java.io.IOException;
import java.nio.file.Path;
import java.util.Map;
import org.junit.jupiter.api.Test;

class OpenApiAggregateTest {

    private static final ObjectMapper YAML = new ObjectMapper(new YAMLFactory());
    private static final Path API_DIR =
            Path.of(System.getProperty("user.dir")).resolve("../../documentation/api").normalize();

    @Test
    void committedAggregateEqualsTheMergeOfTheServiceDocuments() throws IOException {
        OpenApiAggregate.assertMatchesCommitted(API_DIR);
    }

    @Test
    void keepsAppFacingOperationsAndDropsInternalAndMetaOnes() throws IOException {
        JsonNode merged = OpenApiAggregate.merge(OpenApiAggregate.readServices(API_DIR));

        assertTrue(merged.at("/paths/~1v1~1households/post").isObject());
        assertTrue(
                merged.at("/paths").properties().stream()
                        .noneMatch(p -> p.getKey().contains("/internal/")));
        assertFalse(merged.at("/paths").has("/v1/meta"));
        assertFalse(merged.at("/components/schemas").has("ServiceInfo"));
    }

    @Test
    void sameMethodAndPathInTwoServicesFails() throws IOException {
        Map<String, JsonNode> services =
                Map.of(
                        "a-openapi.yaml", document("/v1/x", "get", "listA", "{}"),
                        "b-openapi.yaml", document("/v1/x", "get", "listB", "{}"));

        AssertionError error =
                assertThrows(AssertionError.class, () -> OpenApiAggregate.merge(services));
        assertTrue(error.getMessage().contains("GET /v1/x"), error.getMessage());
    }

    @Test
    void duplicateOperationIdFails() throws IOException {
        Map<String, JsonNode> services =
                Map.of(
                        "a-openapi.yaml", document("/v1/a", "get", "same", "{}"),
                        "b-openapi.yaml", document("/v1/b", "get", "same", "{}"));

        AssertionError error =
                assertThrows(AssertionError.class, () -> OpenApiAggregate.merge(services));
        assertTrue(error.getMessage().contains("operationId same"), error.getMessage());
    }

    @Test
    void sameSchemaNameWithDifferentDefinitionFails() throws IOException {
        Map<String, JsonNode> services =
                Map.of(
                        "a-openapi.yaml",
                        document("/v1/a", "get", "a", "{Dto: {type: string}}"),
                        "b-openapi.yaml",
                        document("/v1/b", "get", "b", "{Dto: {type: integer}}"));

        AssertionError error =
                assertThrows(AssertionError.class, () -> OpenApiAggregate.merge(services));
        assertTrue(error.getMessage().contains("schema Dto"), error.getMessage());
    }

    @Test
    void identicalSharedSchemaIsKeptOnce() throws IOException {
        Map<String, JsonNode> services =
                Map.of(
                        "a-openapi.yaml",
                        document("/v1/a", "get", "a", "{Dto: {type: string}}"),
                        "b-openapi.yaml",
                        document("/v1/b", "get", "b", "{Dto: {type: string}}"));

        JsonNode merged = OpenApiAggregate.merge(services);

        assertEquals(1, merged.at("/components/schemas").size());
        assertEquals(2, merged.at("/paths").size());
    }

    @Test
    void unreferencedSchemaIsPrunedAndMissingOneFails() throws IOException {
        JsonNode merged =
                OpenApiAggregate.merge(
                        Map.of(
                                "a-openapi.yaml",
                                document(
                                        "/v1/a",
                                        "get",
                                        "a",
                                        "{Used: {type: string}, Unused: {type: string}}")));
        assertEquals(1, merged.at("/components/schemas").size());
        assertTrue(merged.at("/components/schemas").has("Used"));

        JsonNode missing = document("/v1/a", "get", "a", "{}");
        AssertionError error =
                assertThrows(
                        AssertionError.class,
                        () ->
                                OpenApiAggregate.merge(
                                        Map.of("a-openapi.yaml", withRef(missing, "Ghost"))));
        assertTrue(error.getMessage().contains("Ghost"), error.getMessage());
    }

    /** A one-operation document whose response references {@code Used} when it is defined. */
    private static JsonNode document(String path, String method, String id, String schemas)
            throws IOException {
        String ref = schemas.contains("Used") ? "Used" : schemas.contains("Dto") ? "Dto" : "";
        String schema =
                ref.isEmpty() ? "{type: string}" : "{$ref: '#/components/schemas/" + ref + "'}";
        return YAML.readTree(
                "openapi: 3.1.0\n"
                        + "paths:\n  "
                        + path
                        + ":\n    "
                        + method
                        + ":\n      operationId: "
                        + id
                        + "\n      responses:\n        '200':\n          description: OK\n"
                        + "          content:\n            application/json:\n"
                        + "              schema: "
                        + schema
                        + "\ncomponents:\n  schemas: "
                        + schemas
                        + "\n");
    }

    private static JsonNode withRef(JsonNode document, String name) throws IOException {
        return YAML.readTree(
                YAML.writeValueAsString(document)
                        .replace(
                                "type: \"string\"", "$ref: \"#/components/schemas/" + name + "\""));
    }
}
