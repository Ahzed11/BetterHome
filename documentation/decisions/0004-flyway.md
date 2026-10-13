# 0004 — Flyway for schema migrations

## Context

Each microservice owns its PostgreSQL database. Schema changes must be forward-only and auditable.

## Decision

Use Flyway SQL migrations under each service's `src/main/resources/db/migration`. Hibernate DDL generation is disabled. In production, migrations run as init containers or one-shot jobs, never at API startup.

## Consequences

`%dev` / `%test` may migrate at start for developer speed. Production images keep `quarkus.flyway.migrate-at-start=false`.
