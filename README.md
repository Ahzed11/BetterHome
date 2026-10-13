# BetterHome

Mobile app (Flutter) and Quarkus microservices for shared-home chores, points, and checklists.

See [documentation/project-specification.md](documentation/project-specification.md) for behavior and [AGENTS.md](AGENTS.md) for contribution rules.

## Status

- **Phase 0** done (T-0001): monorepo, five Quarkus services, Compose + Keycloak, Flyway.
- **Phase 1** done (T-0002): households API + Flutter FR/EN household flows (demo repository by default).
- **Phase 2** done (T-0007): tasks-service templates / quick-log / complete / dismiss / reassign + Flutter chores screen.

## Prerequisites

- JDK 21 (`jbang jdk install 21` works)
- Podman (Compose)
- Flutter (stable) for the app module

## Quick start

```bash
make up          # Postgres :5432, Keycloak :8180
make migrate     # Flyway SQL into each service DB (host psql or podman exec)
make test-backend   # Spotless, Checkstyle, tests, coverage floor; fix formatting with: cd backend && ./mvnw spotless:apply
make test-app
cd app && flutter run   # demo data unless dart-defines set
```

Service HTTP ports: households `8081`, tasks `8082`, scoring `8083`, lists `8084`, notifications `8085`.

Real API from the app:

```bash
cd app && flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8081 \
  --dart-define=ACCESS_TOKEN=<keycloak-access-token>
```

Keycloak demo user setup: [deploy/keycloak/README.md](deploy/keycloak/README.md).
