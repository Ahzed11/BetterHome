# BetterHome

Mobile app (Flutter) and Quarkus microservices for shared-home chores, points, and checklists.

See [documentation/project-specification.md](documentation/project-specification.md) for behavior and [AGENTS.md](AGENTS.md) for contribution rules.

## Status

- **Phase 0** done (T-0001): monorepo, five Quarkus services, Compose + Keycloak, Flyway.
- **Phase 1** done (T-0002): households API + Flutter FR/EN household flows (demo repository by default).
- **Phase 2** done (T-0007): tasks-service templates / quick-log / complete / dismiss / reassign + Flutter chores screen.

## Run it on your own server (NAS)

For using the app rather than developing it. You need a server with Docker Compose v2, a Caddy and Tailscale already running on it (see [deploy/nas](deploy/nas/README.md)), and an Android phone on the same tailnet.

1. On the server: fill in the `CHANGE_ME` values of `deploy/nas/compose.yml`, create a project from it in the Docker app of the UGOS interface (or `docker compose up -d` over SSH), then add the Caddyfile snippet to your Caddy (step by step in [deploy/nas](deploy/nas/README.md#install)).
2. On the phone: install the APK (from the GitHub Release, or `make apk`; see [Try the app on a phone](#try-the-app-on-a-phone)), open it and enter `https://<your-nas>.ts.net`.
3. Tap "Sign up" in the app, create your household, and optionally set up push ([deploy/nas](deploy/nas/README.md#push-notifications-gotify)).

## Prerequisites

- JDK 21 (`jbang jdk install 21` works)
- Podman with a compose provider, and its API socket: `systemctl --user enable --now podman.socket`
- The Podman API must not exit when idle (its default is 5 idle seconds; Testcontainers then fails with `Broken pipe` between test classes). `tooling/install-dev-tools.sh` sets this with `tooling/configure-podman-api.sh`, and `make doctor` checks it
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

CI: [.github/workflows/check.yml](.github/workflows/check.yml) runs the gates of `make check` (docs, one backend job per service, app) and the web end-to-end journeys (`e2e`, Podman Compose stack plus headless Chrome) as parallel jobs on every pull request and on `master`, joined by a `check` job ([ADR 0019](documentation/decisions/0019-ci-runs-the-gates-as-parallel-jobs.md)), with the toolchain versions from `tooling/versions.env` and Docker for Testcontainers. Image builds and the dependency audit are not part of it yet (T-0046, T-0038).

OpenShift manifests (Kustomize, not exercised on a cluster yet): [deploy/openshift/README.md](deploy/openshift/README.md). `make test-openshift-ports` is part of `make check`; `make test-openshift` renders the overlay when kustomize, `oc` or `kubectl` is installed.

Service HTTP ports: households `8081`, tasks `8082`, scoring `8083`, lists `8084`, notifications `8085`.

Real API from the app, signing in through Keycloak (the app uses a Dart client generated from `documentation/api/openapi.yaml`: run `make client` once, and again after the API changes). Keycloak accepts the web redirect only from port 8090:

```bash
make client && cd app && flutter pub get && flutter run -d chrome --web-port 8090 \
  --dart-define=API_BASE_URL=http://localhost:8081 \
  --dart-define=TASKS_API_BASE_URL=http://localhost:8082 \
  --dart-define=SCORING_API_BASE_URL=http://localhost:8083 \
  --dart-define=LISTS_API_BASE_URL=http://localhost:8084 \
  --dart-define=NOTIFICATIONS_API_BASE_URL=http://localhost:8085 \
  --dart-define=KEYCLOAK_ISSUER=http://localhost:8180/realms/betterhome
```

To try the app by hand in one command, run `make run-app`: it starts the stack, creates the users `alice` and `bob` (password `demo`) and serves the web build on http://localhost:8090. Sign in as `alice`, create a household, then add chore templates from the household screen and log chores with "I just did…". `RUN_APP_SEED=1 make run-app` also loads the demo household. Ctrl-C stops the app, `make down` stops the stack. Push notifications are not delivered locally unless you start the optional Gotify server (`podman compose -f deploy/podman-compose.yml --profile gotify up -d`, with `GOTIFY_URL=http://gotify:80` in the environment of `make up`; ADR 0027).

Without `API_BASE_URL` and `KEYCLOAK_ISSUER` the app runs in demo mode on in-memory data. `make seed` creates the users `alice` and `bob` (password `demo`). On the Android emulator use `10.0.2.2` for the API URLs and run `adb reverse tcp:8180 tcp:8180`, because Keycloak advertises `localhost:8180`. After changing the realm file run `make down && make up`, since it is imported only once.

`make seed` creates its demo users itself. Manual Keycloak user setup: [deploy/keycloak/README.md](deploy/keycloak/README.md).

### Try the app on a phone

`make apk` builds `app/build/app/outputs/flutter-apk/app-release.apk` (about 60 MB): a release-mode build signed with the debug key, which is meant for installing by hand, not for publishing. The published APK is built by the `release` workflow with the release key (see below). It checks the file it built (the `INTERNET` permission, the application id, no `.ts.net` name inside).

- **Releases:** push a tag `v<version>` that matches `version:` in `app/pubspec.yaml` (for example `v0.1.0` for `0.1.0+1`). The `release` workflow builds the APK signed with the release key, refuses a debug-signed file, and publishes a GitHub Release with exactly one asset, `betterhome-<version>.apk`; the signing certificate's SHA-256 is in the release notes. The key exists only as the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`, and in the owner's own backup of the keystore. If it is lost, no update can be installed over an existing install.
- **Install:** enable "install unknown apps" for your file manager or browser on the phone, then open the APK, or run `adb install -r app-release.apk` over USB. A debug-signed build does not install over a build signed with another key (another machine's debug key, or a release key): uninstall the old one first.
- **Which server:** the app asks for the server address on first launch (for example `https://nas.example.ts.net`, the name of your server of [deploy/nas](deploy/nas/README.md)), checks that a BetterHome server answers there and remembers it. "Change server" on the sign-in screen asks again. No address is inside the APK, so the same file works for every server. The build-time `--dart-define`s of development and `make e2e` still win when they are set.
- **Sign-in** returns to the app through the redirect `com.betterhome.betterhome:/oauth2redirect`, which the realm already allows. The phone must be on the tailnet (Tailscale app) to reach the server.

End-to-end journeys: `make e2e` runs them on the web build in headless Chrome. Choose the target with `E2E_TARGET=web|android` and reuse a running stack with `E2E_STACK=running` (after `BETTERHOME_TEST_CLOCK_ENABLED=true COMPOSE_PROFILES=gotify GOTIFY_URL=http://gotify:80 make up`: the journeys check that a push reaches Gotify and move the clock of the services through `/v1/test/clock`, which answers 404 unless that variable is true).

## Container images

Every merge into `master` builds the five service images and pushes them to GitHub's container registry as `ghcr.io/<owner>/betterhome-<service>`, tagged with the commit SHA and `latest` ([publish-images.yml](.github/workflows/publish-images.yml), [ADR 0026](documentation/decisions/0026-publish-images-to-ghcr.md)). The packages are public, so pulling needs no login. To build them locally: `cd backend && ./mvnw -DskipTests package`, then `tooling/build-images.sh localhost/betterhome dev`.
