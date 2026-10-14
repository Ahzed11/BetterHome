# 0016 — Real HTTP answers are validated against the committed contract

## Context

ADR 0015 keeps `documentation/api/<service>-openapi.yaml` equal to the code, but nothing checked that what a running service actually answers matches that document. Serialization details (nulls, formats, framework error bodies) can differ from the annotations without any test noticing. AGENTS §5.1 requires that a field the API starts returning without documenting it always fails.

## Decision

Tests validate every REST-assured answer against the committed contract with the Atlassian `openapi-request-validator` (`com.atlassian.oai:openapi-request-validator-restassured`, test scope, Apache-2.0, built on swagger-parser; it reads the OpenAPI 3.1 documents SmallRye generates). `ContractValidation` in the `common-domain` test-jar builds the filter, and each service registers it for all of its tests through a `QuarkusTestBeforeEachCallback`, so no test has to remember to add it. Quarkus infrastructure paths under `/q/` are not part of the API and are skipped.

Only answers are validated: tests send invalid requests on purpose and the validator cannot separate request schema errors from response ones by level. SmallRye does not emit `additionalProperties: false`, so the validator closes every object schema in memory; the committed documents, and the clients generated from them, stay tolerant of future fields. Services omit null fields from JSON (`quarkus.jackson.serialization-inclusion=non-null`) so optional fields are absent rather than `null`, and bean validation failures answer the documented `ErrorResponse`.

## Consequences

An undocumented field, status code, wrong type or format in any real answer fails the build. New endpoints are covered as soon as a test calls them. Validating requests is a separate step (T-0041).
