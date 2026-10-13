# 0006 — A generated Dart client outside `app/`, not committed

## Context

The Flutter app must call APIs without hand-maintained DTOs that drift from OpenAPI.

## Decision

Generate a Dart client into `generated/` (gitignored) from `documentation/api/openapi.yaml`. The app depends on that output. CI fails if generation or the contract drifts.

## Consequences

Agents and CI regenerate the client; it is never committed. Guard scripts live under `make test-guard`.
