package com.betterhome.common.openapi;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Keeps {@code documentation/api/<service>-openapi.yaml} equal to the document the running service
 * generates from its annotations. The comparison is on the parsed trees, so formatting never
 * matters, but any added, removed or changed path, field or status code fails the build. Regenerate
 * with {@code make openapi} (system property {@code openapi.update=true}) and review the diff.
 */
public final class OpenApiContract {

    private static final ObjectMapper YAML = new ObjectMapper(new YAMLFactory());

    private OpenApiContract() {}

    public static void assertMatchesCommitted(String service, String generatedYaml)
            throws IOException {
        Path committed =
                Path.of(System.getProperty("user.dir"))
                        .resolve("../../../documentation/api")
                        .resolve(service + "-openapi.yaml")
                        .normalize();
        if (Boolean.getBoolean("openapi.update")) {
            Files.createDirectories(committed.getParent());
            Files.writeString(committed, generatedYaml, StandardCharsets.UTF_8);
            return;
        }
        if (!Files.exists(committed)) {
            throw new AssertionError(
                    committed + " does not exist; generate it with `make openapi` and commit it");
        }
        JsonNode expected = YAML.readTree(Files.readString(committed, StandardCharsets.UTF_8));
        JsonNode actual = YAML.readTree(generatedYaml);
        if (!expected.equals(actual)) {
            throw new AssertionError(
                    "The "
                            + service
                            + " API no longer matches "
                            + committed.getFileName()
                            + ": run `make openapi`, review the diff and commit it");
        }
    }
}
