# 0006 — A generated Dart client outside `app/`, not committed

## Context

The Flutter app must call APIs without hand-maintained DTOs that drift from OpenAPI.

## Decision

Generate a Dart client into `generated/` (gitignored) from `documentation/api/openapi.yaml`. The app depends on that output. CI fails if generation or the contract drifts.

## Consequences

Agents and CI regenerate the client; it is never committed. Guard scripts live under `make test-guard`.

## Addendum (T-0020): how it is generated and guarded

`tooling/generate-client.sh` (`make client`) runs the `dart` generator of OpenAPI Generator, pinned in `tooling/versions.env` (version and SHA-256 of the Maven Central jar), and writes `generated/betterhome_api`. The app depends on it as a path package; `make test-app` and CI generate it first. The app keeps its own domain models; each `Http*Repository` calls the generated API classes and maps the answer in `lib/data/api_mappers.dart`, so no JSON is parsed by hand. `make test-guard` shows that generation fails on a dangling reference or an unparseable document, and that the app stops compiling when a field it reads disappears from the contract (with a control run on the real contract). Repository tests run against `ContractServer` (`app/test/support`), a fake server built from `documentation/api/openapi.yaml`.

