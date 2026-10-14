package com.betterhome.common.openapi;

import com.atlassian.oai.validator.OpenApiInteractionValidator;
import com.atlassian.oai.validator.model.Request;
import com.atlassian.oai.validator.report.LevelResolver;
import com.atlassian.oai.validator.report.ValidationReport;
import com.atlassian.oai.validator.restassured.OpenApiValidationFilter;
import com.atlassian.oai.validator.restassured.RestAssuredResponse;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import io.restassured.RestAssured;
import io.restassured.filter.Filter;
import io.restassured.response.Response;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * Validates real HTTP exchanges against the committed {@code
 * documentation/api/<service>-openapi.yaml}. Install it on a REST-assured request with {@code
 * .filter(ContractValidation.of("households"))}: the call then fails when the status code is not
 * documented, a header or the body does not match its schema, or the body carries a field the
 * schema does not declare. {@link OpenApiContract} keeps the document equal to the code; this keeps
 * the answers equal to the document.
 *
 * <p>Only answers are judged: tests deliberately send invalid or unauthenticated requests to see
 * the error answers, so request content and credentials are not validated. A call to a path or
 * method the contract does not know still fails.
 *
 * <p>SmallRye does not emit {@code additionalProperties: false}, and the validator only rejects
 * unknown fields on schemas that declare it. The contract is therefore closed in memory before it
 * is handed to the validator, so the committed document (and the clients generated from it) stay
 * tolerant of future fields while our own answers may never carry an undocumented one.
 */
public final class ContractValidation {

    private static final ObjectMapper YAML = new ObjectMapper(new YAMLFactory());
    private static final String INFRASTRUCTURE_PREFIX = "/q/";
    private static final ConcurrentMap<String, Filter> FILTERS = new ConcurrentHashMap<>();

    private ContractValidation() {}

    /**
     * Makes every REST-assured call of the running test validate its answer against the committed
     * contract of {@code service}, so new tests are covered without remembering to add a filter.
     * Quarkus infrastructure endpoints under {@code /q/} (health, OpenAPI, metrics) are not part of
     * the API contract and are left alone. Meant for a {@code QuarkusTestBeforeEachCallback}.
     */
    public static void installFor(String service) {
        Filter validation = FILTERS.computeIfAbsent(service, s -> apiOnly(of(s)));
        RestAssured.replaceFiltersWith(validation);
    }

    private static Filter apiOnly(Filter validation) {
        return (request, response, context) ->
                request.getURI().contains(INFRASTRUCTURE_PREFIX)
                        ? context.next(request, response)
                        : validation.filter(request, response, context);
    }

    /** Filter validating every answer against the committed contract of {@code service}. */
    public static Filter of(String service) {
        return of(committedContract(service));
    }

    /** Filter validating every answer against the contract file at {@code contract}. */
    public static Filter of(Path contract) {
        LevelResolver strict =
                LevelResolver.create()
                        .withLevel(
                                "validation.schema.additionalProperties",
                                ValidationReport.Level.ERROR)
                        .build();
        OpenApiInteractionValidator validator =
                OpenApiInteractionValidator.createFor(closedCopy(contract).toUri().toString())
                        .withLevelResolver(strict)
                        .build();
        return (request, response, context) -> {
            Response answer = context.next(request, response);
            ValidationReport report =
                    validator.validateResponse(
                            URI.create(request.getURI()).getPath(),
                            Request.Method.valueOf(request.getMethod()),
                            RestAssuredResponse.of(answer));
            if (report.hasErrors()) {
                throw new OpenApiValidationFilter.OpenApiValidationException(report);
            }
            return answer;
        };
    }

    /** Location of the committed contract of {@code service}. */
    public static Path committedContract(String service) {
        return Path.of(System.getProperty("user.dir"))
                .resolve("../../../documentation/api")
                .resolve(service + "-openapi.yaml")
                .normalize();
    }

    private static Path closedCopy(Path contract) {
        try {
            JsonNode document = YAML.readTree(Files.readString(contract, StandardCharsets.UTF_8));
            forbidUnknownFields(document);
            Path closed = Files.createTempFile("closed-contract-", ".json");
            closed.toFile().deleteOnExit();
            Files.writeString(closed, document.toString(), StandardCharsets.UTF_8);
            return closed;
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot read the contract " + contract, e);
        }
    }

    private static void forbidUnknownFields(JsonNode node) {
        if (node instanceof ObjectNode schema
                && "object".equals(schema.path("type").asText())
                && schema.has("properties")
                && !schema.has("additionalProperties")) {
            schema.put("additionalProperties", false);
        }
        node.forEach(ContractValidation::forbidUnknownFields);
    }
}
