# BetterHome

Mobile app (Flutter) and Quarkus microservices for shared-home chores, points, and checklists.

See [documentation/project-specification.md](documentation/project-specification.md) for behavior and [AGENTS.md](AGENTS.md) for contribution rules.

## Phase 0 status

**Done.** Monorepo layout, five Quarkus services, Flyway baselines, Keycloak + Postgres via Podman Compose, shared `AuthVerifier` / `Clock` / `PushSender` seams. See `documentation/tasks.md` (T-0001).

## Prerequisites

- JDK 21 (`jbang jdk install 21` works)
- Podman (Compose)
- Flutter (stable) for the app module
- `psql` for `make migrate`

## Quick start

```bash
make up          # Postgres :5432, Keycloak :8180
make migrate     # Flyway SQL into each service DB
make test-backend
```

Service HTTP ports: households `8081`, tasks `8082`, scoring `8083`, lists `8084`, notifications `8085`.

Keycloak demo user setup: [deploy/keycloak/README.md](deploy/keycloak/README.md).
