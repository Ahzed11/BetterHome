# 0007 — A parsed-document check against OpenAPI drift

## Context

Undocumented response fields and silent contract changes break clients.

## Decision

Validate real HTTP responses against `documentation/api/openapi.yaml` in CI. Drift fails the build.

## Consequences

Every new field or path updates OpenAPI in the same change. Phase 0 establishes the document; full response validation lands with domain endpoints.
