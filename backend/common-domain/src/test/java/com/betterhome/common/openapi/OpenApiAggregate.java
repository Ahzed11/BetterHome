package com.betterhome.common.openapi;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.stream.Stream;

/**
 * Builds the one app contract {@code documentation/api/openapi.yaml} from the per-service documents
 * ({@code <service>-openapi.yaml}). Operations tagged {@code internal} (service-to-service) or
 * {@code meta} (per-service info) are left out, as are the schemas only they used. The merge fails
 * when two services declare the same method and path, the same operation id, or a schema of the
 * same name with a different definition, so names stay unique across services.
 */
public final class OpenApiAggregate {

    private static final ObjectMapper YAML = new ObjectMapper(new YAMLFactory());
    private static final Set<String> EXCLUDED_TAGS = Set.of("internal", "meta");
    private static final String SCHEMA_REF = "#/components/schemas/";

    private OpenApiAggregate() {}

    /** Merges the parsed service documents, keyed by file name, into the app contract. */
    public static JsonNode merge(Map<String, JsonNode> services) {
        Map<String, JsonNode> paths = new TreeMap<>();
        Map<String, JsonNode> schemas = new TreeMap<>();
        Map<String, JsonNode> securitySchemes = new TreeMap<>();
        Map<String, String> operationIds = new TreeMap<>();
        Set<String> tags = new TreeSet<>();
        new TreeMap<>(services)
                .forEach(
                        (service, document) -> {
                            mergePaths(service, document, paths, operationIds, tags);
                            mergeUnique(service, "schema", document, "schemas", schemas);
                            mergeUnique(
                                    service,
                                    "security scheme",
                                    document,
                                    "securitySchemes",
                                    securitySchemes);
                        });
        return document(paths, schemas, securitySchemes, tags);
    }

    private static void mergePaths(
            String service,
            JsonNode document,
            Map<String, JsonNode> paths,
            Map<String, String> operationIds,
            Set<String> tags) {
        document.path("tags")
                .forEach(
                        tag -> {
                            if (!EXCLUDED_TAGS.contains(tag.path("name").asText())) {
                                tags.add(tag.path("name").asText());
                            }
                        });
        document.path("paths")
                .properties()
                .forEach(
                        path -> {
                            ObjectNode kept = YAML.createObjectNode();
                            path.getValue()
                                    .properties()
                                    .forEach(
                                            operation -> {
                                                if (isAppFacing(operation.getValue())) {
                                                    kept.set(
                                                            operation.getKey(),
                                                            operation.getValue());
                                                    claim(
                                                            service,
                                                            path.getKey(),
                                                            operation,
                                                            paths,
                                                            operationIds);
                                                }
                                            });
                            if (!kept.isEmpty()) {
                                ObjectNode merged =
                                        paths.containsKey(path.getKey())
                                                ? (ObjectNode) paths.get(path.getKey())
                                                : YAML.createObjectNode();
                                kept.properties()
                                        .forEach(
                                                operation ->
                                                        merged.set(
                                                                operation.getKey(),
                                                                operation.getValue()));
                                paths.put(path.getKey(), merged);
                            }
                        });
    }

    private static boolean isAppFacing(JsonNode operation) {
        for (JsonNode tag : operation.path("tags")) {
            if (EXCLUDED_TAGS.contains(tag.asText())) {
                return false;
            }
        }
        return true;
    }

    private static void claim(
            String service,
            String path,
            Map.Entry<String, JsonNode> operation,
            Map<String, JsonNode> paths,
            Map<String, String> operationIds) {
        String where = operation.getKey().toUpperCase() + " " + path;
        if (paths.containsKey(path) && paths.get(path).has(operation.getKey())) {
            throw new AssertionError(where + " is declared by more than one service: " + service);
        }
        String id = operation.getValue().path("operationId").asText("");
        if (id.isEmpty()) {
            throw new AssertionError(service + ": " + where + " has no operationId");
        }
        String other = operationIds.put(id, service);
        if (other != null) {
            throw new AssertionError(
                    "operationId " + id + " is used by " + other + " and " + service);
        }
    }

    private static void mergeUnique(
            String service,
            String what,
            JsonNode document,
            String section,
            Map<String, JsonNode> target) {
        document.path("components")
                .path(section)
                .properties()
                .forEach(
                        entry -> {
                            JsonNode previous =
                                    target.putIfAbsent(entry.getKey(), entry.getValue());
                            if (previous != null && !previous.equals(entry.getValue())) {
                                throw new AssertionError(
                                        what
                                                + " "
                                                + entry.getKey()
                                                + " is defined differently by "
                                                + service);
                            }
                        });
    }

    private static JsonNode document(
            Map<String, JsonNode> paths,
            Map<String, JsonNode> schemas,
            Map<String, JsonNode> securitySchemes,
            Set<String> tags) {
        ObjectNode root = YAML.createObjectNode();
        root.put("openapi", "3.1.0");
        ObjectNode info = root.putObject("info");
        info.put("title", "BetterHome API");
        info.put("version", "1.0.0-SNAPSHOT");
        ArrayNode tagList = root.putArray("tags");
        tags.forEach(tag -> tagList.addObject().put("name", tag));
        ObjectNode pathNode = root.putObject("paths");
        paths.forEach(pathNode::set);
        ObjectNode components = root.putObject("components");
        ObjectNode schemaNode = components.putObject("schemas");
        reachable(paths, schemas).forEach(name -> schemaNode.set(name, schemas.get(name)));
        ObjectNode securityNode = components.putObject("securitySchemes");
        securitySchemes.forEach(securityNode::set);
        return root;
    }

    /** Schema names used by the kept operations, directly or through other schemas. */
    private static Set<String> reachable(
            Map<String, JsonNode> paths, Map<String, JsonNode> schemas) {
        Set<String> seen = new TreeSet<>();
        Deque<String> todo = new ArrayDeque<>();
        paths.values().forEach(path -> refs(path, todo));
        while (!todo.isEmpty()) {
            String name = todo.pop();
            if (!schemas.containsKey(name)) {
                throw new AssertionError("Schema " + name + " is referenced but not defined");
            }
            if (seen.add(name)) {
                refs(schemas.get(name), todo);
            }
        }
        return seen;
    }

    private static void refs(JsonNode node, Deque<String> into) {
        List<JsonNode> pending = new ArrayList<>(List.of(node));
        while (!pending.isEmpty()) {
            JsonNode current = pending.remove(pending.size() - 1);
            if (current.has("$ref") && current.get("$ref").asText().startsWith(SCHEMA_REF)) {
                into.push(current.get("$ref").asText().substring(SCHEMA_REF.length()));
            }
            Iterator<JsonNode> children = current.elements();
            while (children.hasNext()) {
                pending.add(children.next());
            }
        }
    }

    /** Reads every {@code *-openapi.yaml} in {@code apiDir}. */
    public static Map<String, JsonNode> readServices(Path apiDir) throws IOException {
        Map<String, JsonNode> services = new TreeMap<>();
        try (Stream<Path> files = Files.list(apiDir)) {
            for (Path file : files.filter(f -> f.toString().endsWith("-openapi.yaml")).toList()) {
                services.put(
                        file.getFileName().toString(),
                        YAML.readTree(Files.readString(file, StandardCharsets.UTF_8)));
            }
        }
        return services;
    }

    /** Fails when the committed {@code openapi.yaml} differs from the merge of the services. */
    public static void assertMatchesCommitted(Path apiDir) throws IOException {
        JsonNode merged = merge(readServices(apiDir));
        Path committed = apiDir.resolve("openapi.yaml");
        if (Boolean.getBoolean("openapi.update")) {
            Files.writeString(committed, YAML.writeValueAsString(merged), StandardCharsets.UTF_8);
            return;
        }
        if (!Files.exists(committed)) {
            throw new AssertionError(
                    committed + " does not exist; generate it with `make openapi` and commit it");
        }
        if (!YAML.readTree(Files.readString(committed, StandardCharsets.UTF_8)).equals(merged)) {
            throw new AssertionError(
                    "openapi.yaml no longer matches the merge of the service documents: run"
                            + " `make openapi`, review the diff and commit it");
        }
    }
}
