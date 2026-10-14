# BetterHome

Mobile app (Flutter) and Quarkus microservices for shared-home chores, points, and checklists.

See [documentation/project-specification.md](documentation/project-specification.md) for behavior and [AGENTS.md](AGENTS.md) for contribution rules.

## Status

- **Phase 0** done (T-0001): monorepo, five Quarkus services, Compose + Keycloak, Flyway.
- **Phase 1** done (T-0002): households API + Flutter FR/EN household flows (demo repository by default).
- **Phase 2** done (T-0007): tasks-service templates / quick-log / complete / dismiss / reassign + Flutter chores screen.

## Prerequisites

- JDK 21 (`jbang jdk install 21` works)
- Podman with a compose provider, and its API socket: `systemctl --user enable --now podman.socket`
- Flutter, Chrome for Testing (web end-to-end), the Android SDK and an emulator image for the app module

Versions are pinned in [tooling/versions.env](tooling/versions.env). On Fedora, `tooling/install-dev-tools.sh`
installs Flutter, Chrome for Testing, the Android SDK, the emulator image and a `betterhome-test` AVD under your home directory
(it uses `sudo dnf` only if system packages are missing and accepts the Android SDK licenses).
`make doctor` reports anything missing. `source tooling/dev-env.sh` puts the tools on your shell `PATH`;
the Makefile does this on its own. OpenShift Local is not needed: Podman Compose is the target platform for now.

## Quick start

```bash
make up          # builds the jars and images, starts Postgres :5432, Keycloak :8180, runs Flyway, starts the five services, then smoke-checks them
make seed        # demo household: users alice and bob (password demo), "Demo Home", three templates; safe to rerun
make migrate     # Flyway as one-shot containers per service DB (make up already runs it)
make down        # remove containers, volumes and built images
make test-backend   # Spotless, Checkstyle, tests, coverage floor; fix formatting with: cd backend && ./mvnw spotless:apply
make test-app
cd app && flutter run   # demo data unless dart-defines set
```

Tokens from the host (`localhost:8180`) and services inside Compose (`keycloak:8180`) share one issuer: Keycloak runs with `KC_HOSTNAME=http://localhost:8180` and `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true` (see `deploy/podman-compose.yml`); issuer validation stays on. `make smoke` re-runs the readiness and authenticated-call check.

CI: [.github/workflows/check.yml](.github/workflows/check.yml) runs `make check` (docs, backend, app) on every pull request and on `master`, with the toolchain versions from `tooling/versions.env` and Docker for Testcontainers. E2E, image builds and the dependency audit are not part of it yet (T-0021, T-0046, T-0038).

Service HTTP ports: households `8081`, tasks `8082`, scoring `8083`, lists `8084`, notifications `8085`.

Real API from the app (the app uses a Dart client generated from `documentation/api/openapi.yaml`: run `make client` once, and again after the API changes):

```bash
make client && cd app && flutter pub get && flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8081 \
  --dart-define=ACCESS_TOKEN=<keycloak-access-token>
```

`make seed` creates its demo users itself. Manual Keycloak user setup: [deploy/keycloak/README.md](deploy/keycloak/README.md).

End-to-end journeys: `make e2e` runs them on the web build in headless Chrome. Choose the target with `E2E_TARGET=web|android` and reuse a running stack with `E2E_STACK=running` (after `make up`).
