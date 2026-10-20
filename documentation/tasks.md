# Task ledger

Shared memory for agents and humans. Read before starting; update before finishing. See AGENTS.md §12.

## Done

### T-0001 · Phase 0 foundations (monorepo, Quarkus, Flyway, Keycloak)

* Status: done
* Issue / PR: — / on `master`
* Depends on: —
* Spec: §7, §10 Phase 0
* Summary: Monorepo with five Quarkus services, `common-domain` seams (`AuthVerifier`, `Clock`, `PushSender`), Flyway baselines, Podman Compose (Postgres five DBs + Keycloak realm import), Flutter skeleton, ADRs, Makefile, and OpenAPI stub.
* Decisions and deviations: Local stack is Podman Compose first (ADR 0003); OpenShift/CRC manifests deferred. `make migrate` uses host `psql` or `podman exec` into Compose Postgres. SELinux volume mounts use `:Z`. e2e / OWASP / generated-client guard remain stubs until later phases.
* Verification: `make test-docs`; `make test-backend`; `make up` (Postgres healthy, Keycloak realm `betterhome`); `make migrate` (all five DBs). `make check` runs docs + backend (+ Flutter when present). Full e2e not required for Phase 0.
* Follow-ups: T-0004 (OpenShift manifests), T-0005 (OWASP + OpenAPI client guard), e2e when journeys exist.

### T-0002 · Phase 1 households domain (users, memberships, invitations, away)

* Status: done
* Issue / PR: — / on `master`
* Depends on: T-0001
* Spec: §2, §10 Phase 1
* Summary: Backend households-service covers user sync, household CRUD, memberships/roles/leave, invitations, and away. Flutter app adds FR/EN profile sync, household list/create/detail, invite, accept-token, and away toggles via `HouseholdsRepository` (HTTP + in-memory demo).
* Decisions and deviations: `PUT /v1/me` upserts the local user from client-supplied claims. Invitation TTL defaults to 7 days. App defaults to `FakeHouseholdsRepository`; real API via `--dart-define=API_BASE_URL` + `ACCESS_TOKEN`. Keycloak AppAuth and full emulator e2e deferred (T-0006). Away → task reassignment remains T-0003.
* Verification: `make test-docs`; `make test-backend`; `make test-app` (widget tests EN/FR + repository unit tests). Demo-mode app launched on Chrome (`flutter run -d chrome`). Emulator e2e against Keycloak not run.
* Follow-ups: T-0003, T-0006.

### T-0007 · Phase 2 tasks domain (templates, quick-log, complete, dismiss, reassign)

* Status: done
* Issue / PR: — / on `master`
* Depends on: T-0002
* Spec: §3.1–3.3 (except scheduler spawning / reversion), §10 Phase 2
* Summary: tasks-service Flyway V2 (templates, rotations, tasks); admin templates; create open occurrence; member quick-log (manual done); complete (on-time/late via `points_awarded`); dismiss; admin reassign + `reassign-away` hook. Flutter chores screen (All/Mine, quick-log, complete/dismiss with confirm). OpenAPI in `tasks-openapi.yaml`.
* Decisions and deviations: Membership checks use `InMemoryMembershipGateway` (HTTP client to households-service is T-0008). Scoring ledger not written (Phase 3). Recurrence scheduler not run (Phase 4). Points stored on the task row as `points_awarded` for later ledgering.
* Verification: `make test-docs`; `make test-backend` (incl. TaskPhase2Test + RoundRobinTest); `make test-app` (chores widget + tasks repository tests).
* Follow-ups: T-0003 (wire households away → reassign-away), T-0008 (HTTP MembershipGateway).

### T-0009 · Phase 3 scoring (ledger, reversions, scoreboard)

* Status: done
* Issue / PR: — / on `master`
* Depends on: T-0007
* Spec: §3.3 Reversion, §3.4, §10 Phase 3
* Summary: scoring-service Flyway V2 (point_transaction, task_reversion, monthly_recap); award/reverse/adjust ledger; scoreboard week/month/year/all-time with podium and effort shares; close-month winners + celebrate. tasks-service awards via `InMemoryPointsLedgerClient` and admin `POST .../revert`. Flutter leaderboard (FR/EN) with period switcher; chores award/reverse against scoring repository.
* Decisions and deviations: Period bounds use UTC (household timezone deferred). Tasks↔scoring and scoring membership use in-memory gateways (HTTP clients: T-0008 / T-0010). Month-end scheduler not automated (admin `close-month` endpoint). Demo FakeScoringRepository seeds sample podium data once per household.
* Verification: `make test-docs`; `make test-backend` (ScoringPhase3Test, TaskPhase3ScoringWireTest); `make test-app` (leaderboard widgets EN/FR, scoring repository tests). Emulator e2e against Keycloak not run.
* Follow-ups: T-0010 (HTTP PointsLedgerClient + scoring MembershipGateway); month-end Quartz job; household-TZ period windows.

### T-0011 · Phase 4 automation (recurrence, scheduler, outbox, reminders)

* Status: done
* Issue / PR: — / on `master`
* Depends on: T-0007, T-0009
* Spec: §3.1–3.3 Spawning/assignment, §5, §10 Phase 4
* Summary: tasks-service V3 (`task_recurrence`, `notification_outbox`); `RruleEngine` (daily/weekly/monthly + DST); Quarkus scheduler claims due rows with `FOR UPDATE SKIP LOCKED`, catch-up spawn + supersede in one transaction; fixed/RR with away fallback and `nobody_available`; outbox drained via `PushSender`; due reminders from household settings. Flutter admin “Make recurring” + demo spawn. OpenAPI updated.
* Decisions and deviations: Lightweight in-repo RRULE subset (no ical4j). Scheduler disabled in `%test`. HTTP `runDue` not exposed (scheduler owns prod spawning; Fake repo supports demo spawn). Real FCM/APNs gateway still `NoOpPushSender`.
* Verification: `make test-docs`; `make test-backend` (RruleEngineTest, TaskPhase4AutomationTest); `make test-app` (recurrence widget + repository tests). Emulator e2e / Keycloak not run.
* Follow-ups: overdue push type; richer RRULE UI; wire real PushSender.

## In progress

_(none)_

## Roadmap

Milestones in delivery order (vertical slice first). A milestone is reached when its exit criterion holds and its tasks are `done`. Reached on 2026-10-14: M1, M2, M3 and M4 (see the notes on each).

* **M1 · Real sign-in works** — T-0013, T-0014, T-0036. Exit: A Keycloak user can call every service, and invitations work over HTTP. **Reached.**
* **M2 · Toolchain, local stack, gates, CI** — T-0015, T-0016, T-0017, T-0005, T-0018. Exit: `make up` runs all five services; `make check` enforces AGENTS §5.3 and runs in CI on every pull request. **Reached**, except what the product owner parked: the dependency audit (T-0038), and image builds in `make check` (T-0046).
* **M3 · Services wired for real** — T-0010, T-0019. Exit: No in-memory gateway or ledger client left in main code; one app contract describes every endpoint. **Reached.**
* **M4 · App vertical slice on the real stack** — T-0020, T-0006, T-0021, T-0022. Exit: The app signs in through Keycloak and runs households, chores and leaderboard against `make up`; `make e2e` runs in CI. **Reached** (web target; Android sign-in not run, T-0045).
* **M5 · Lists (spec Phase 5)** — T-0023 (done), T-0024 (done). Exit: The Groceries tab journey passes end to end. **Reached** (the tab is named "Lists" in the design; reached from the household screen until the bottom bar, T-0031).
* **M6 · Notifications** — T-0025 (done), T-0026 (done), T-0027, T-0028, T-0086, T-0012, T-0077. Exit: Every notification type in spec §5 reaches a fake push gateway in the user's language, honoring preferences.
* **M7 · Spec completeness and polish (spec Phase 6)** — T-0029, T-0030, T-0031, T-0088, T-0089, T-0090, T-0032, T-0033, T-0076, T-0078. Exit: Every rule in spec §2–§9 is implemented and covered by an end-to-end journey.
* **M8 · Deploy and launch** — T-0004, T-0034, T-0035. Exit: The stack runs on OpenShift with migrations as Jobs, and signed store builds are produced. Blocked until an OpenShift cluster is available; until then Podman Compose is the target platform.

## Todo

### T-0015 · Developer toolchain: Flutter and the Android emulator

* Status: done
* Issue / PR: #8 / #36
* Depends on: —
* Spec: AGENTS §5.3, §6
* Acceptance criteria: Install and pin the Flutter SDK and the Android SDK with a headless emulator image on the development machine. OpenShift Local and `oc` are not needed: there is no cluster for now and Podman Compose is the target platform (see T-0004). Document versions and setup in README. Add `make doctor` that fails when a required tool or version is missing (JDK 21 via jbang, Podman and its socket, `podman compose` provider, Flutter, emulator).
* Summary: `tooling/versions.env` pins Flutter 3.47.7 (Dart 3.13.5), Android command-line tools 13114758, platform android-35, build-tools 35.0.0, the `google_apis` x86_64 image and the `betterhome-test` AVD, with SHA-256 checksums for both downloads. `tooling/install-dev-tools.sh` installs them idempotently under `$HOME` (uses `sudo dnf` only when system packages are missing, accepts the Android SDK licenses). `tooling/dev-env.sh` puts them on `PATH`; `make doctor` (`tooling/doctor.sh`) fails on anything missing; the Makefile now finds jbang, Flutter and the Android tools by itself. `tooling/start-emulator.sh` starts the headless AVD. README documents the setup. A second commit adopts the `pubspec.lock` and `analysis_options.yaml` changes that Flutter 3.47.7 writes on first use.
* Decisions and deviations: OpenShift Local / `oc` dropped from scope (decision of 2026-10-13). Installed with the `claude` account's sudo authorization granted by the product owner for this purpose; the script itself never stores a password. The emulator is installed and the AVD created, but the emulator process does NOT yet stay up on this VM: see T-0045. Lockfile and analyzer excludes are tool-written consequences of pinning the SDK, committed separately so they can be reviewed apart.
* Verification: `make doctor` passes (13 checks) and fails with exit 1 and six `MISSING` lines when the SDK path is wrong. `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze` (no issues) and `flutter test` (13 tests) pass with Flutter 3.47.7 from `app/`. NOT verified: an emulator boot (crashes, T-0045), `make test-app`/`make check` as a whole, e2e, CI.
* Follow-ups: T-0045 (emulator crash).

### T-0016 · `make up` and `make seed` run the full local stack

* Status: done
* Issue / PR: #9 / #38
* Depends on: T-0013, T-0014, T-0015
* Spec: §7, AGENTS §6.1, ADR 0003
* Acceptance criteria: Podman Compose starts Postgres, Keycloak (realm import) and all five services as containers built with the Quarkus container extension; services get their DB URL, OIDC settings and service-account secrets from environment variables (no committed secrets: realm secrets injected at import). `make migrate` runs Flyway per service as one-shot containers. `make seed` creates a demo household with two members and sample templates through the public APIs. `make down` cleans everything. Verified by a scripted smoke check.
* Summary: `deploy/podman-compose.yml` now runs Postgres, Keycloak and the five services (prod profile, images from the existing `Dockerfile.jvm` files over the fast-jar in `target/quarkus-app`; no new Quarkus extension or library). `make up` packages the jars, starts Postgres and Keycloak, runs `make migrate`, starts the services, then runs `deploy/smoke.sh`. `make migrate` (`deploy/migrate.sh`) now runs the official Flyway image once per service database on the Compose network (real checksums; replaces the hand-rolled psql loader). `make seed` (`deploy/seed.sh`) creates users alice and bob with kcadm, then uses password-grant tokens to call `PUT /v1/me`, create "Demo Home", invite and accept, and add three templates; rerunning skips what exists. `make smoke` waits for `/q/health/ready` on :8081-:8085 and sends one Keycloak token to every service. `make down` removes containers, volumes and built images.
* Decisions and deviations: Issuer: Keycloak runs with `KC_HOSTNAME=http://localhost:8180` and `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true`, so `iss` is always `http://localhost:8180/realms/betterhome` while services fetch discovery and JWKS at `keycloak:8180`; issuer validation stays on. Secrets: only the local-dev placeholder already in the realm file (`local-dev-only-change-me`), supplied to tasks-service through `OIDC_SERVICE_CLIENT_SECRET` (overridable from the host environment); demo users use the password `demo`, created at seed time, never in the realm file. Services start after migrations, which is why `make up` orders it that way. Compose project name stays `betterhome` (fixed), so two stacks cannot run at once. Kept Flyway outside the services (`migrate-at-start=false` unchanged).
* Verification: see the PR description for the commands run. Not run: Flutter, e2e, CI. Limit found: after completing a task as the assignee, `GET :8083/v1/households/{id}/scoreboard` returns 403 because scoring-service has no real membership gateway yet and tasks-service does not call scoring over HTTP (T-0010); points on the scoreboard cannot be shown until then.
* Follow-ups: T-0010 (scoring wiring, needed for the scoreboard step), T-0046 (#37: image build in `make check`/CI, Dockerfile EXPOSE).

### T-0017 · Backend quality gates: format, lint, coverage

* Status: done
* Issue / PR: #10
* Depends on: T-0015
* Spec: AGENTS §5.3
* Acceptance criteria: `make test-backend` runs spotless check, checkstyle (or PMD/SpotBugs) and JaCoCo with a coverage floor that cannot drop, then the Quarkus tests. Existing violations are fixed in the same change, no suppressions. Gate failures fail `make check`.
* Summary: Root `backend/pom.xml` now runs, in `validate`, Spotless (google-java-format 1.28.0, AOSP style, unused imports removed) and Checkstyle 10.21.4 with `backend/config/checkstyle.xml`, and in `verify` JaCoCo report + line-coverage floor. Checkstyle encodes AGENTS §2 Forbidden: `@SuppressWarnings`, `@Disabled`/`@Ignore`, `catch (Throwable)`, empty catch blocks, TODO/FIXME without an issue number, system-clock calls (only `SystemClock` and tests exempt), star and unused imports. Services use `quarkus-jacoco`; a Maven Enforcer rule fails the build when the coverage file is missing. `.mvn/jvm.config` opens the compiler modules google-java-format needs. Floors (line coverage, just below measured): households 0.82, tasks 0.70, scoring 0.62, lists 0.90, notifications 0.90, common-domain 0.09.
* Decisions and deviations: Checkstyle only (no PMD/SpotBugs), since the AGENTS gate lists them as alternatives; revisit if needed. Existing violations fixed: a formatting sweep of 44 files (own commit, no behavior change) and one `@SuppressWarnings` in `RecurrenceSpawnService` that was unnecessary and is removed. google-java-format 1.37.0 does not run on this JDK, hence the 1.28.0 pin. The floors are measured values, not targets: raise them as tests land. The dependency audit stays in T-0005. Coverage tooling is not wired into the aggregate `make check` beyond `make test-backend`.
* Verification: `./mvnw -B clean verify` in `backend/` on JDK 21 passes. Negative checks run and reverted: each Checkstyle rule trips on a deliberately bad file (including `@Disabled` and unused import in tests); a floor of 0.99 fails scoring with "Rule violated"; a clean build without tests fails with "No coverage data". `make`, Flutter, e2e and CI were not run.
* Follow-ups: T-0037 (common-domain direct unit tests and a higher floor).

### T-0018 · CI: run `make check` on every pull request

* Status: done
* Issue / PR: #11 / #43
* Depends on: T-0016, T-0017
* Spec: AGENTS §6.2
* Acceptance criteria: GitHub Actions workflow with pinned tool versions runs `make check` (docs, backend, app, policy, guard) on pull requests and on `master`. Podman or Docker available for Testcontainers. The e2e job is added by T-0021.
* Summary: `.github/workflows/check.yml` runs `make check` (docs, backend with Spotless/Checkstyle/JaCoCo/OpenAPI contract tests, app with dart format/analyze/test) on every pull request and on pushes to `master`, on `ubuntu-24.04`, with `contents: read`, a 45 min timeout and `concurrency` cancelling superseded runs. JDK 21 Temurin and the Flutter version are read from `tooling/versions.env` (single source). Maven (setup-java cache) and pub (flutter-action cache) are cached. Testcontainers / Dev Services use the runner's Docker via `DOCKER_HOST=unix:///var/run/docker.sock` (overrides the Makefile's `?=` Podman default); nothing else in `check` needs Podman.
* Decisions and deviations: Actions pinned to commit SHAs with the tag in a comment: `actions/checkout` v7.0.1, `actions/setup-java` v6.0.1 (first-party), `subosito/flutter-action` v2.23.0 (third-party, the de facto Flutter setup action; chosen over a manual SDK download to get version pinning plus caching; revisit if it becomes unmaintained). A `flutter pub get --enforce-lockfile` step precedes `make check` because a fresh checkout has no package config (without it `flutter_lints` did not resolve and `dart format` produced a false diff); the Makefile is untouched. `make check` does not include `test-policy`/`test-guard` (stubs, not part of `check`), e2e (T-0021), image builds (T-0046) or the OWASP audit (T-0038, needs an NVD key). The Flutter golden tests ran in `flutter test` on Linux per ADR 0012. No README badge added. Branch protection requiring the `check` job is a repository setting, not done here.
* Verification: green run on PR #43: https://github.com/Ahzed11/BetterHome/actions/runs/38448075987 (all of `make check`, 5m29s). First run https://github.com/Ahzed11/BetterHome/actions/runs/38447223563 failed at `dart format` before the pub get step existed. Deliberately red run (throwaway PR #48, a badly formatted Java line, closed and branch deleted): https://github.com/Ahzed11/BetterHome/actions/runs/38448888249 failed in Spotless. Not run: e2e.
* Follow-ups: T-0021 adds the e2e job here; T-0046 images; T-0038 audit. T-0053 (#49): require the `check` job on `master` (branch protection).

### T-0019 · One app contract: merge the generated per-service OpenAPI documents

* Status: done
* Issue / PR: #12 / #62
* Depends on: T-0010
* Spec: §7 API style, ADR 0006, ADR 0007
* Acceptance criteria: `documentation/api/openapi.yaml` is produced by merging the per-service documents generated in T-0005 (app-facing operations of all services; operations tagged `internal` excluded) and is guarded the same way (a test fails when the committed aggregate differs from the merge). Operation ids and schema names must stay unique across services.
* Summary: `OpenApiAggregate` (common-domain test-jar) merges the five service documents into `documentation/api/openapi.yaml` (41 paths, 53 operations, 51 schemas); `OpenApiAggregateTest` fails when the committed file differs from the merge and when two services collide on method and path, operation id, or schema name with different content (tests on tampered inputs). `make openapi` regenerates the service documents, then the aggregate.
* Decisions and deviations: `meta` operations (`/v1/meta`, present in all five services) are excluded like `internal` ones, since they are per-service info and not app-facing. Defect found and fixed: households-openapi documented `POST .../tasks/dismiss-away/{userId}` with no operationId, a path households does not serve; SmallRye was scanning the `TasksClient` REST client. It is now excluded with `mp.openapi.scan.exclude.classes`, which removes 16 lines from `households-openapi.yaml`. Schemas only used by dropped operations are pruned.
* Verification: JDK 21, Podman. `make openapi` (service documents unchanged except the households phantom path, aggregate written), `make test-backend` (Spotless, Checkstyle, all services' tests, floors, contract tests, `OpenApiAggregateTest` 7 tests) and `make test-docs` pass. Negative check: renaming a path in the committed `openapi.yaml` fails the test with "no longer matches"; reverted. Not run: app, e2e. The local Compose stack was torn down with `make down` because it held ports 8081-8085 (its session had crashed); a first `make test-backend` hit one Postgres container start timeout, the rerun was green.

### T-0020 · Generated Dart client replaces hand-written repositories

* Status: done
* Issue / PR: #13 / #63
* Depends on: T-0019, T-0005
* Spec: ADR 0006, AGENTS §2, §5.2
* Acceptance criteria: Generate the Dart client from `openapi.yaml` into the gitignored `generated/` folder; app repositories use it with bearer headers. Remove hand-written JSON parsing and `dynamic`. Repository tests run against a fake server built from the contract, not hand-built JSON. `make test-guard` proves generation fails when the document or client is broken.
* Summary: `make client` (`tooling/generate-client.sh`) generates `generated/betterhome_api` with OpenAPI Generator 7.26.0's `dart` generator (jar pinned by version and SHA-256 in `tooling/versions.env`, SHA-1 cross-checked against Maven Central). The app depends on it as a path package. `Http{Households,Tasks,Scoring}Repository` call the generated API classes (bearer header from `HttpBearerAuth`) and map answers in `lib/data/api_mappers.dart`; every `fromJson` is gone. `test/support/contract_server.dart` is a fake server built from `openapi.yaml` (rejects undeclared method/path/query, checks request bodies against the schemas, builds answers from the response schemas); `test/http_repositories_test.dart` runs all three repositories against it, plus error, 401, missing-field and every-enum-value cases. `make test-guard` (`tooling/test-guard.sh`, part of `make check`) shows generation fails on a dangling reference and on an unparseable document, and that the app stops compiling when `HouseholdResponse.createdBy` is renamed in the contract (with a control run on the real contract). CI generates the client before `pub get`; `make test-app` and `make e2e` depend on `make client`.
* Decisions and deviations: Domain models and the repository interfaces stay (screens, fakes and goldens unchanged); only the HTTP implementations changed. `dart` generator (plain `http`, no build_runner) chosen over `dart-dio`. New dev dependency `yaml` (test server). Real defect fixed on the way: `award` and `reverse` in scoring-service need the `service` role since T-0010, and tasks-service already writes the ledger, yet the app called them with the user's token (403 on the real stack). They are now tagged `internal` (so out of the app contract, `scoring-openapi.yaml` and `openapi.yaml` regenerated), removed from `ScoringRepository` and from `chores_screen.dart`; `FakeTasksRepository` takes the `FakeScoringRepository` as `ledger` so the demo scoreboard still moves. The contract marks no response field as required, so generated models are all nullable and each mapper checks the fields it needs through `need` (no `!`), see T-0071. The generator writes unset optional request fields as `null`; services accept it (as the old code sent it) and the test server treats it as "not sent". The access token is still a fixed string; T-0006 replaces it with a supplier.
* Verification: JDK 21, Podman, Flutter 3.47.7. `make test-docs`, `make test-backend`, `make test-app` (format, analyze, 138 tests incl. 13 new, goldens unchanged), `make test-guard`, and `make e2e` (web, from the running stack: profile sync and create household through the generated client) pass. Not run: Android target, CI (this PR's run is the evidence), manual UI run of chores/leaderboard against the stack (e2e covers only the first journey).
* Follow-ups: T-0071 (required response fields), T-0006/T-0069 (sign-in, token supplier), more e2e journeys.

### T-0021 · `make e2e`: real app on an emulator against the real stack

* Status: done
* Issue / PR: #14 / #57, #66, #65, #68
* Depends on: T-0006, T-0016, T-0015
* Spec: AGENTS §6.2
* Acceptance criteria: `make e2e` boots the stack, applies migrations, launches the app on a headless Android emulator, signs in through Keycloak and runs `integration_test` journeys. Adds a controllable clock exposed only in the test environment and a fake push gateway endpoint. CI job added to the T-0018 workflow. Each later feature task adds its journey here.
* Summary (first increment): `make e2e` runs the `integration_test` journey in `app/integration_test/` against the real Compose stack. Target is picked with `E2E_TARGET=web|android` (default `web`); `E2E_STACK=running` reuses a stack already up. `tooling/e2e.sh` boots the stack, creates the test user, gets a Keycloak token and launches the target; web uses headless Chrome for Testing + chromedriver, pinned with checksums in `tooling/versions.env`, installed by `install-dev-tools.sh`, checked by `make doctor`. Services allow the web origin through CORS in the local stack. The first journey is profile sync then create household, answered by the real services.
* Decisions and deviations: web first by the product owner's decision (the Android emulator crashes on this VM, T-0045); ADR 0018; AGENTS §6.1/§6.2 reworded for the selectable target. The test user's token is injected with `--dart-define` because the app has no sign-in yet (T-0006) and `flutter_appauth` has no web support (T-0069).
* Verification: from a cold start (`make down`, then `make e2e`) the web journey passed; again with `E2E_STACK=running`; an unknown target exits 2; `make test-app` and `make test-docs` pass. NOT run: the `android` target (never booted here), `make test-backend` (no backend code changed), CI.
* Summary (journeys increment, after sign-in T-0006): the web target now runs three things against the real stack: the real Keycloak browser sign-in (`app/test_driver/web_sign_in.dart`), then `integration_test` driving the UI with tokens for alice and bob: sign in/profile sync and create a household; admin creates a template and quick-logs a manual task; an open task is completed by its assignee; a second one is dismissed after confirmation; the admin reverts a completion with a reason; the leaderboard shows 10 then 5 points (tasks to scoring over HTTP, scoring to households); alice invites bob and bob joins with the token. `tooling/e2e.sh` fetches the tokens right before the journeys (they expire in about five minutes, shorter than the builds before them).
* Product bugs found by the journeys and fixed: the Compose stack gave tasks-service no `SCORING_SERVICE_URL` and scoring-service neither the households URL nor its service client, so completing a task and reading the scoreboard answered 503 (the T-0016 scoreboard limit); fixed in `deploy/podman-compose.yml`.
* Verification (journeys): cold `make down` then `make e2e` passed (sign-in journey and both `integration_test` journeys); `make test-app`, `make test-guard`, `make test-docs` pass. A first cold run once timed out waiting for the app to start in the sign-in journey and passed on rerun (see T-0074). NOT run: the `android` target, CI.
* Scope split (ledger cleanup, 2026-10-14): done for what M4 needs: `make e2e` boots the stack, applies migrations, runs the web journeys (real Keycloak sign-in, households, chores, leaderboard, invite and join) and runs in CI as the `e2e` job (T-0073). Four parts of the original criteria are not met here and moved: the headless Android target (web first by the product owner, ADR 0018; the emulator crash is T-0045), the controllable clock with the journeys that need it (T-0076), the fake push gateway endpoint (T-0077), and `e2e` inside the local `make check` (T-0078).
### T-0022 · Golden and accessibility baseline for existing screens

* Status: done
* Issue / PR: #15 / 47
* Depends on: T-0015
* Spec: AGENTS §5.2, spec §8
* Acceptance criteria: Golden tests (light mode, Linux per ADR 0012) for design-system widgets and the households, chores and leaderboard screens. Accessibility checks: 44 px touch targets, text contrast, semantic labels, 200% text scaling without overflow, in FR and EN.
* Summary: `app/test/screens_baseline_test.dart` renders profile sync, households, create household, household detail, chores and leaderboard in their loading, empty, error and populated states (where reachable), each in FR and EN: a golden, the four Flutter accessibility guidelines (Android and iOS tap targets, labeled tap targets, text contrast) and a 200% text-scale overflow check. `app/test/design_system_test.dart` does the same for a showcase of the theme and tokens. 37 goldens live in `app/test/goldens/`; test doubles for loading and failing repositories are in `app/test/support/`.
* Decisions and deviations: Goldens use Flutter's default Ahem test font, so text is blocks (deterministic on Linux, layout-only protection); readable fonts are a follow-up. The repo has no standalone design-system widgets, so the showcase composes the themed Material widgets and token swatches. Defect fixed: household detail member rows overflowed at 200% text scale in French (ListTile trailing button consumed the tile); rows are now a Row with an expanded label column and a flexible action button. Not reachable without production changes: non-admin views (the households fake hosts only one member). No new dependency.
* Verification: `make test-app` (format, analyze, 125 tests including 37 goldens); `make update-goldens` run twice with no diff; a deliberate +1 px change to `AppTokens.spaceMd` failed 21 tests and was reverted. Not run: integration_test, emulator (T-0045), dark mode.
* Follow-ups: T-0057, T-0058, T-0059.

### T-0023 · lists-service: checklists, items and bulk reset

* Status: done
* Issue / PR: #16 / #53
* Depends on: T-0008, T-0016
* Spec: §4, §2 permissions, §6.2 LIST/ITEM
* Acceptance criteria: Flyway schema for LIST and ITEM with constraints; admins create, rename and archive lists; any member adds, edits, checks, unchecks and soft-deletes items (who and when); bulk reset unchecks all items. Membership through households internal endpoints with a service account (ADR 0014). Authorization matrix tests for every endpoint (admin, member, non-member, left member, other household). OpenAPI updated.
* Summary: Migration V2 adds `list` and `item` (FK item to list, NOT NULL, CHECKs for non-blank title, position >= 0, completer/completed_at and deleted_by/deleted_at set together, unique position per list; no cross-service FK). Endpoints under `/v1/households/{id}/lists`: list (`includeArchived`), create, rename, archive (admin) and, for any active member, list/add/rename/check/uncheck/delete items and `POST .../reset`. Rules live in the `Checklist`/`ChecklistItem` entities and `ChecklistService`/`ItemService`; membership comes from households-service through `HttpMembershipGateway` with the `betterhome-lists-service` service account (realm export and Compose updated).
* Decisions and deviations: Archived lists answer 409 Conflict to rename, archive again and every item change (reading items stays allowed); deleted items answer 404. Checking a checked item (or unchecking an unchecked one) is a no-op, so the first completer is kept. Positions are append-only (max incl. deleted + 1, list row locked on add) and never reused. Delete returns 204; reset returns the items. Spec gap: who may reset is not stated; implemented as any active member (bulk uncheck), see Discovered T-0061. `@Consumes(JSON)` is on body-bearing methods only so body-less POST actions do not answer 415 (see T-0062). No ADR: it reuses ADR 0014/0015. After merging T-0039 (answer validation against the contract), lists-service also omits null fields (`quarkus.jackson.serialization-inclusion=non-null`) and answers bean validation failures with `ErrorResponse` through a `ConstraintViolationMapper`, like the other services.
* Verification: `make test-backend` (JDK 21; Spotless, Checkstyle, all five services' tests, JaCoCo floors, contract tests) passed; lists-service has 64 tests, line coverage 98.3%, floor raised 0.90 to 0.97. `make test-docs` OK. Live: `make up`, `make seed`, then as alice (admin) and bob (member) over HTTP on :8084 created a list, added/checked/unchecked/renamed/soft-deleted items (row keeps deleted_by/deleted_at in Postgres), reset, archived; bob got 403 on create/rename/archive, 409 on adding to the archived list, anonymous 401, unknown household 403; `make down`. Not run: Flutter, e2e, CI.
* Follow-ups: T-0061 (reset permission), T-0062 (415 on body-less POSTs elsewhere), T-0063 (anonymization on account deletion).

### T-0024 · App: Lists tab (groceries and other checklists)

* Status: done
* Issue / PR: #17 / #71
* Depends on: T-0023, T-0020
* Spec: §4, §8.2
* Acceptance criteria: Fourth bottom tab with list overview and item screen: create, check, uncheck, delete, reset (admin actions hidden for members). FR/EN strings, loading/empty/error/populated widget tests, goldens. e2e journey "checklist create, check, delete, reset". Changed by the product owner on 2026-10-14: the UI follows the Claude Design canvas ("Lists" board) and is built from clean, reusable components.
* Summary: `ListsRepository` (generated client over lists-service, plus an in-memory fake) and `ListsScreen`, one screen as in the design: header with household name and "Uncheck all", a pill per list with the open count, an add field, the open items in a card and checked items under "In the basket". Admins also see the add pill and a menu to rename or archive the selected list. Members add, check, uncheck, delete and reset. Failed requests show a snackbar. Reusable widgets in `app/lib/ui/widgets/` (`AppPill`, `AppAddPill`, `AppCard`, `ScreenHeader`, `SectionLabel`, `CheckRow`, `AddField`) built on new tokens (`AppTokens`, `AppTypography`). Strings FR/EN; `LISTS_API_BASE_URL` for the app; the e2e journey creates a list, adds, checks, deletes and resets items through the real UI.
* Decisions and deviations: ADR 0021 (design canvas as reference, widget rules, deviations). Not built: the bottom bar with four tabs and the household switcher (Lists opens from the household screen like Chores and the leaderboard; the shell is T-0031), the design's fonts (T-0079), member names beside checked items (T-0058). Reset is offered to every member, as the service allows (open question T-0061). Spec §8.2 now names the fourth tab "Lists", as in the design. The accessibility baseline (48 px targets, labels, contrast) found and fixed three defects in the first widget draft: pills and check boxes of 44 px, semantics merged into the parent, and a pill without a tap action.
* Verification: JDK 21, Podman, Flutter 3.47.7. `make test-docs`, `make test-app` (format, analyze, 231 tests including the widget showcase, the lists screen in EN/FR, contract-server tests for the lists repository, goldens, accessibility, 200% text scale), `make test-guard`, and `make e2e` from a cold start (web sign-in journey, then the household, chores, lists and invite journeys against the real stack) pass. Not run: Android, backend tests (no backend change).
* Follow-ups: T-0079 (fonts), T-0080 (restyle existing screens with the shared widgets), T-0031 (bottom bar and household switcher).

### T-0025 · notifications-service core: inbox, preferences, rendering

* Status: done
* Issue / PR: #18 / #55
* Depends on: T-0016
* Spec: §5, §6.2 NOTIFICATION/PREFERENCE
* Acceptance criteria: notifications-service owns NOTIFICATION and PREFERENCE. Internal ingest endpoint (service role) accepts typed events with an idempotency key; it renders FR/EN text server-side in the recipient's language, applies per-type preferences, stores the notification and hands it to `PushSender`. App-facing API: list notifications, mark read, read/update preferences. ADR records the event contract and ownership.
* Summary: notifications-service owns NOTIFICATION and PREFERENCE (Flyway, CHECK/unique constraints). `POST /v1/internal/notifications` (role `service`) is idempotent on `idempotencyKey`, renders FR/EN in the recipient's language (read from households through a new internal user lookup by id and token subject), applies per-type preferences and stores the in-app notification. App API: list own notifications, mark read, list and update preferences. Local Compose wiring and the Keycloak `betterhome-notifications-service` client are included.
* Decisions and deviations: event contract and ownership in ADR 0017. Handing notifications to `PushSender` is not part of this change: device tokens and the FCM/APNs sender are T-0027, relays are T-0026. Only the `in_app` channel is stored here. After merging T-0039 (answer validation against the contract), notifications-service also omits null fields (`quarkus.jackson.serialization-inclusion=non-null`) and answers bean validation failures with `ErrorResponse` through a `ConstraintViolationMapper`, like the other services. The Keycloak realm file now holds the lists and notifications service clients side by side.
* Verification: notifications tests (52 across the module, incl. authorization matrix, schema constraints, rendering, real-token auth, OpenAPI contract) and scoring and lists modules pass under `./mvnw verify` with Spotless, Checkstyle and the JaCoCo floor (notifications line coverage 98.3%, floor 0.97). Live: `make up`, `make seed`, `make smoke` OK with all five services; with a service token an event created a notification for the recipient, a repeat of the same key answered `duplicate`, a user token got 403, and each member read only their own notification. NOT run: the tasks-service tests fail in this run (T-0065, a wall-clock dependent test unrelated to this change), so the single full `make test-backend` was not green and was completed per module; e2e (T-0021, blocked by T-0045) and the Flutter gates were not run.
* Follow-ups: T-0065 (flaky tasks reminder test, #54). T-0026 relays, T-0027 push, T-0028 app inbox.


### T-0026 · Outbox relays into notifications-service

* Status: done
* Issue / PR: #19 / #73
* Depends on: T-0025
* Spec: §5, AGENTS §3 Push
* Acceptance criteria: tasks-service relays its outbox to notifications-service instead of calling `PushSender` directly; households-service gets an outbox for marked-away and invitation events. Relays claim rows with SKIP LOCKED, deliver at least once, and are idempotent on the receiving side. Tests cover retries and duplicate delivery.
* Summary: Both services write `notification_outbox` rows in the transaction of the change and run an `OutboxRelay` (every 15 s, one row per transaction, `FOR UPDATE SKIP LOCKED`) that sends them to `POST /v1/internal/notifications` with key `<service>:<row id>`; retries back off from 5 s to 15 min, a permanent refusal parks the row. tasks: migration V6 (attempts, available_at, failed_at; title/body nullable and no longer written; waiting rows get `taskTitle` in their payload), payload is now a JSON map of short strings (a title with quotes is escaped properly), `PushSender` is no longer called by tasks. households: migration V3 (outbox with FKs and a type CHECK), `marked_away` queued in `setAway`, `invitation` queued when the invited email has an account, new Keycloak client `betterhome-households-service` and Compose wiring (`NOTIFICATIONS_SERVICE_URL`). Shared `NotificationEvent`, `NotificationsGateway`, `NotificationDeliveryException`, `RelayBackoff` in `common-domain`.
* Decisions and deviations: ADR 0017 addendum (relay rules, who produces what) and ADR 0014 addendum (households service account). An invitation for an email without an account queues nothing, because ingest needs a recipient user. A future-dated away period still notifies when it is set. Only the types the services already produce are relayed; the other spec §5 types have no producer (T-0081). Duplicate relay code per service (small, different entities); the shared pieces are in `common-domain`.
* Verification: JDK 21, Podman. `make test-backend SERVICE=tasks-service` (73 tests: relay delivery, key and payload, backoff and retry with a fixed clock, parking, lost answer sent again with the same key, 4 concurrent relays send 40 rows once each, rollback leaves no event, HTTP gateway status mapping) and `SERVICE=households-service` (57 tests: both producers, rollback on a failed away change, relay suite, HTTP gateway) pass with Spotless, Checkstyle and the coverage floors. Live on `make up` + `make seed`: marking a member away, inviting an existing user and a spawned recurrence each produced the notification in the recipient's language; with notifications-service stopped an invite still answered 201, the event retried with backoff, and after the restart it was delivered once (no duplicate). `make e2e` and the full `make test-backend` are in the PR run. Not run: Android.
* Follow-ups: T-0081 (producers for the other types), T-0082 (the away text says chores were passed on, they are dismissed), T-0083 (drop the unused title and body columns of tasks' outbox).

### T-0027 · Real push delivery: FCM and APNs

* Status: todo
* Issue / PR: #20
* Depends on: T-0025
* Spec: §5, AGENTS §8
* Acceptance criteria: Device-token registration API, FCM/APNs implementation of `PushSender` in notifications-service, minimal payloads (IDs and short text), invalid-token cleanup. Tests use an in-memory fake of the vendor boundary; e2e uses the fake push endpoint from T-0021.

### T-0028 · App: notification inbox and preferences

* Status: done
* Issue / PR: #21 / #79
* Depends on: T-0025, T-0020, T-0024
* Spec: §5
* Acceptance criteria: Split by the product owner on 2026-10-14: this task is the inbox and the preferences, which need only the notifications API that exists (T-0025); the push permission prompt and token registration moved to T-0086. Inbox screen reachable from the home screen with an unread count, read state (open one to mark it read, mark all read) and paging; a preferences screen with a toggle per notification type and channel. Built from the shared widgets and tokens (ADR 0021); the design canvas has only a bell icon on the Chores board, no inbox board, so the screens extend its look. FR/EN, widget and golden tests, e2e journey (a member invited by an admin finds the invitation in the inbox).
* Summary: `NotificationsRepository` (generated client plus an in-memory fake) and three UI pieces: `NotificationsScreen` (newest first, a dot and bold title while unread, tap an unread one to mark it read, "Mark all read", "Load more" using the API's `before` cursor, empty/loading/error states), `NotificationPreferencesScreen` (a card per type with a push and an in-app switch, all on by default) and `NotificationsBell` on the home screen with a coral dot while something is unread. New widgets `ToggleRow` and `NotificationRow`, a shared `runGuarded` that shows a snackbar when a request fails (the lists screen uses it too), FR/EN strings including the nine type names, `NOTIFICATIONS_API_BASE_URL`. Titles and bodies are the server-rendered text in the user's language.
* Decisions and deviations: ADR 0021 addendum. The e2e journey differs from the acceptance text: an invitation only produces a notification when the invited email already has an account, which is not the case in the invite journey, so the journey marks bob away through the API and bob reads that notification in the UI (and changes a setting). The bell shows a dot, not a count. Preferences are per user and not per household, as the API is. The inbox lives behind the bell on the home screen until the navigation shell of T-0031 exists.
* Verification: JDK 21, Podman, Flutter 3.47.7. `make test-docs`, `make test-app` (format, analyze, 300 tests: contract-server tests for the repository incl. both new enums, fake repository, inbox, preferences and bell flows in EN/FR, widget states and semantics, goldens, accessibility and 200% text scale for every new screen), `make test-guard`, and a cold `make e2e` (web sign-in, then the household, chores, lists, invite and the new notifications journeys through the relays and notifications-service) pass. Not run: Android.
* Follow-ups: T-0086 (push permission and token registration), T-0031 (shell with the bell and the household switcher).

### T-0029 · Scoring in household time and automated month end

* Status: done
* Issue / PR: #22 / #81 (backend), #82 (app)
* Depends on: T-0010
* Spec: §3.4, §5
* Acceptance criteria: Week/month/year windows computed in the household timezone; a scheduled job closes each month at the household's local boundary (SKIP LOCKED, one transaction per household) and records the winner. App shows the recap and confetti once per user. Clock-controlled tests across timezones and DST.
* Summary (backend, #81): `PeriodWindows` computes every window in the household timezone (Monday weeks, local midnights, DST-safe) and the scoreboard and the admin close use it; windows now include their end. `MembershipGateway.householdZone` reads the zone from households' internal settings (UTC when unknown or invalid, 503 when unreachable). `month_close_cursor` (migration V4) plus `MonthCloser` and a 5-minute scheduler close each household's ended months at its local boundary: one household per transaction, claimed with `FOR UPDATE SKIP LOCKED`, missed months caught up, empty months skipped, existing recaps left alone, a timezone change re-checked when the stored time passes, a households outage retried after a minute. The winners list returns `celebrated`. ADR 0022; spec §3.4 states the local-time cuts, the automatic close and the tie-break.
* Summary (app): the leaderboard shows the recap of the newest unseen month once, with `ConfettiBurst` falling over `MonthRecapDialog`: "You won September 2026 with 20 points!" for the winner, "<name> won ..." for the others, "Nobody scored in ..." for an empty month, plus the household total. It is recorded as seen before it is shown. `ScoringRepository.markRecapCelebrated`, `MonthlyWinner.celebrated`, FR/EN strings.
* Decisions and deviations: Product decision of 2026-10-14: every member sees the recap with confetti once, not only the winner (spec §3.4 updated). Tie goes to the lowest user id (same order as the scoreboard ranks); the old admin close picked an arbitrary one. A month nobody scored in gets no recap row. No jqwik dependency: the invariants run over every JDK zone in a plain test; property tests are T-0030. A timezone change that moves the boundary earlier takes effect only at the stored close time (ADR 0022). Months missed are shown one per visit. Names of other winners are raw ids until T-0058.
* Verification: JDK 21, Podman, Flutter 3.47.7, GitHub Actions unavailable so the local gate (AGENTS.md). Backend (#81): `PeriodWindowsTest` (14, every JDK zone), `ScoreboardTimezoneTest` (7), `MonthCloseTest` (16 with a fixed clock: boundaries in Brussels, UTC and New York, DST both ways, catch-up, idempotency, tie-break, negative sums, hand-closed recaps, timezone change, households outage, registration, limit, four replicas close 24 households once each), gateway zone cases, `celebrated` over HTTP; `make check` and a cold `make e2e` passed. App: contract-server tests for the new call, fake repository, nine recap flows on the leaderboard (winner, other, nobody, once only on a fresh visit, already seen, several months, server cannot record, failing board, French), widget tests for the confetti (decoration only, reduced motion) and the dialog, goldens and accessibility incl. 200% text scale (found and fixed an overflow of the first dialog), `make check` and a cold `make e2e` in the PR. Not covered: an e2e journey through a real month end (needs the controllable clock, T-0076); Android.
* Follow-ups: T-0030 (property and concurrency tests), T-0076, T-0058 (member names).

### T-0030 · Scheduler concurrency and invariant tests

* Status: done
* Issue / PR: #23 / #83
* Depends on: T-0017
* Spec: AGENTS §5.1
* Acceptance criteria: Concurrency tests with several scheduler instances prove no double spawn or double close. jqwik property tests: round robin never picks an ineligible member, ledger sum equals awarded minus reversed points, scores never go negative. Pitest run on tasks and scoring documented.
* Summary: jqwik 1.10.2 added as a test dependency (approved by the product owner on 2026-10-14; ADR 0023). Properties: `RoundRobinPropertiesTest` (never an ineligible member, also when the eligible set changes every round; everyone before anyone twice; no repeat in a row), `RruleEnginePropertiesTest` (occurrences in order, within start and end, on named days, no day skipped, no month clamped, and an exact brute-force oracle in any zone across DST), `PeriodWindowsPropertiesTest` (every zone and instant between 2000 and 2100), `LedgerRulesPropertiesTest` (the rules for every int, and a state machine over random awards, reversals and adjustments: books add up, a task never goes below zero, no score shown below zero). The two ledger rules and the score clamp were extracted into a pure `LedgerRules` that the services call (same behavior). `LedgerSequenceTest` runs seeded random sequences through the real service and PostgreSQL against an independent model. Concurrency: new `SpawnConcurrencyTest` (four schedulers, 20 due recurrences, each spawned once); month close, outbox relays and the reminder and overdue jobs already had such tests (T-0026, T-0081, T-0085, T-0029). Pitest: `make mutation` (profile `pitest`, domain classes only); last run tasks `RoundRobin` + `RruleEngine` 95% (42 of 44), scoring `LedgerRules` + `PeriodWindows` 100% (17 of 17); the first run was 66% for tasks, which led to the exact oracle property.
* Decisions and deviations: Properties run on pure code because jqwik cannot start Quarkus; the database wiring is covered by seeded random sequences and the concurrency tests instead. The two surviving mutants (`nextOccurrence`, lines 41 and 45) are guards made unreachable by the earlier day logic. Pitest is opt-in (not in `make check`), as AGENTS §5.3 says "periodically". `.jqwik-database` ignored by git.
* Verification: JDK 21, Podman, GitHub Actions unavailable so the local gate (AGENTS.md): `make check` (docs, all six backend modules incl. the new tests, app 321 tests, guard) and a cold `make e2e` are recorded in the PR; `make mutation` as above. Not run: Android.
* Follow-ups: T-0087 (the ledger can go below zero), T-0058 etc. unchanged.

### T-0031 · App: navigation shell and household switcher

* Status: done
* Issue / PR: #24 / #85
* Depends on: T-0020, T-0024, T-0028
* Spec: §8.2
* Acceptance criteria: Split by the product owner on 2026-10-14 (the overdue tone, the reverted reason and the quick-log undo moved to T-0088, T-0089 and T-0090). The four bottom tabs (All Chores, My Chores, Leaderboard, Lists) and a household switcher at the top, with the notifications bell reachable from the shell. Built from the shared widgets and tokens (ADR 0021) following the design canvas. The switcher lists the user's households, the choice survives a restart, and every screen reads the selected household. FR/EN, widget and golden tests, e2e journey "household switcher with two households".
* Summary: `HomeShell` (switcher pill and sheet in `household_switcher.dart`, bell, sign-out, `NavigationBar`) replaces `HouseholdsScreen`. `ChoresScreen` takes `mine` instead of its own two tabs, and the chores, leaderboard and lists screens use a `ScreenHeader` rather than an app bar. `AppSession` keeps `selectedHouseholdId` (`ensureSelection`, `selectHousehold`) and remembers it per user in `shared_preferences`. The details of a household (members, invite, accept, away, leave) open from the sheet; its three navigation buttons were removed. French tab labels are now "Toutes les tâches" and "Mes tâches".
* Decisions and deviations: ADR 0021 addendum (design has no switcher board; `shared_preferences` becomes a direct dependency, already transitive). The household list screen and its goldens and the strings `householdsTitle`, `openChores`, `openLeaderboard`, `openLists` are removed as obsolete. The notification preferences screen is still reached from the inbox, not from the shell. Tab bodies reload when a tab or household is selected (no kept state across tabs). An invited user with no household still has no way to accept an invitation before creating one (as before; accept lives in the household details).
* Verification: `make test-docs`, `make test-app` (345 tests incl. shell behaviour tests: tabs, switching, restart, vanished household, creating from the sheet, details, empty state, FR; new goldens `home_*`, `household_sheet`, `chores_mine`), a cold `make e2e` including the new journey "household switcher: two households each show their own chores"; results in the PR. Not run: Android.
* Follow-ups: T-0090 can start; suggested: let a user with no household accept an invitation from the empty state.

### T-0088 · App: overdue in soft coral with "still +N"

* Status: done
* Issue / PR: #24 / #86
* Depends on: T-0031
* Spec: §8.1, §3.3
* Acceptance criteria: An overdue open task is shown in the soft coral token (never red) with the points that are still possible after the due date ("still +N", N = late points). FR/EN, widget and golden tests, and the overdue case in the chores e2e journey.
* Summary: `OverdueBadge` widget ("Overdue · still +2" / "En retard · encore +2") replaces the status line of an open chore whose `dueAt` has passed (strictly after; done, dismissed and reverted chores never show it). `TasksRepository.createOpen` takes an optional `dueAt` (the API already had it), used by tests and the e2e journey to create a chore that is already late.
* Decisions and deviations: ADR 0021 addendum: the text stays dark on a coral tint because the coral alone fails text contrast. The label says "still +N" without "pts" as the spec writes it. T-0031's status is set to done here (it merged as in-review).
* Verification: `make test-app` (358 tests: overdue widget tests incl. the boundary, done-after-due, FR, colour; contract test that `dueAt` is sent; goldens `chores_overdue`), `make check`, cold `make e2e` with the overdue chore in the chores journey; results in the PR. Not run: Android.
* Follow-ups: none.

### T-0089 · App: a reverted task shows its reason to the assignee

* Status: done
* Issue / PR: #24 / #87
* Depends on: T-0031
* Spec: §3.3 (reversion), §8
* Acceptance criteria: When an admin reverts a task, the assignee sees the reason on the task in the app (the task API exposes the latest reversion reason, documented in OpenAPI, spec and contract tests). FR/EN, widget and golden tests, and an e2e journey "admin reverts with a reason and the assignee sees it".
* Summary: tasks-service: migration `V8__task_reversion_reason.sql` (nullable `reversion_reason`, non-blank check), set by `TaskService.revert` with the trimmed reason and exposed as `reversionReason` in `TaskResponse` (OpenAPI regenerated). The app maps it into `ChoreTask`; the chores list shows "Reverted: <reason>" under the status of any chore that is not done (reverted, reopened or dismissed as `reverted_overdue`), FR "Annulée : …". The fake repository sets it too.
* Decisions and deviations: the reason is a copy on the task; the reversion record stays in scoring-service. It is returned to every member who can read the task, not only the assignee (tasks are visible household-wide, and the spec does not restrict it). A task reverted again gets the new reason; one completed again stops showing the old one in the app (the API still returns it until the next reversion). The e2e journey has one user, alice, who is admin and assignee, so it checks what the assignee sees but not a second member's view; the service test reads it as the member.
* Verification: `make test-backend` (new service tests: reason stored trimmed for manual, reopened and overdue-dismissed reversions, read back as the member, replaced by a later reversion, blank refused by the database; contract tests), `make test-app` (widget tests incl. FR and done-again, contract mapping test, goldens `chores_reverted`), `make check`, cold `make e2e` with "Reverted: Not clean" in the chores journey; results in the PR. Not run: Android.
* Follow-ups: none.

### T-0090 · Quick-log "+ I just did…" with single tap and 5-second cancel

* Status: done
* Issue / PR: #24 / #88
* Depends on: T-0031
* Spec: §8.2
* Acceptance criteria: Decided by the product owner on 2026-10-14: whoever quick-logs a task has 5 seconds to cancel their log. Built as delayed logging: picking a template shows a snackbar with Undo for 5 seconds and the task is only sent to the server when they pass without a cancel (nothing is created or reverted if cancelled; the ledger stays append-only). Leaving the screen within the 5 seconds sends the log. The spec text "5-second undo" says this. FR/EN, widget and e2e coverage ("quick-log a manual task and cancel it", "quick-log and keep it").
* Summary: reusable `runUnlessUndone` (snackbar with Undo, 5 s window, action run afterwards, failure shown as a snackbar) used by the chores screen's quick-log; new strings `undo` and `quickLogPending`; spec §8.2 updated. Widget tests: waits the full window (not logged at 4 s), Undo logs nothing even after 10 s, switching tab inside the window still logs, a refused log is reported, FR.
* Decisions and deviations: the owner's wording "cancel their log" was read as option (c), delayed logging (the one recommended in the split), so no backend change. The "restyle the picker after the design" part of the earlier text is not done: the picker keeps its dialog (the e2e journeys and tests rely on it) and the restyle is T-0091. Leaving the app (closing it) inside the window loses the log, as nothing was sent.
* Verification: `make test-app` (374 tests), `make check`, cold `make e2e` with the cancel journey (Undo, then nothing on the server, then a real quick-log); results in the PR. Not run: Android.
* Follow-ups: T-0091.

### T-0032 · Account deletion and anonymization

* Status: todo
* Issue / PR: #25
* Depends on: T-0016, T-0025
* Spec: §9 Privacy, AGENTS §8
* Acceptance criteria: Deleting an account removes or anonymizes the user in Keycloak through the Admin REST API and anonymizes their data in every service while keeping the ledger consistent. Last-admin rule enforced. Tests in each service plus an e2e journey.

### T-0033 · Activity log

* Status: todo
* Issue / PR: #26
* Depends on: —
* Spec: §6.1, §6.2 ACTIVITY_LOG
* Acceptance criteria: Blocked: the spec lists ACTIVITY_LOG but does not say which service owns it, which actions are logged, or where users see it. Needs a product decision and a spec update before implementation.

### T-0034 · Observability: tracing and request IDs

* Status: todo
* Issue / PR: #27
* Depends on: T-0016
* Spec: §7, AGENTS §8
* Acceptance criteria: OpenTelemetry tracing across services and outgoing REST calls, request IDs in MDC and JSON logs, no tokens, emails or message content in logs. Verified on the local stack.

### T-0035 · Release pipeline and store listings

* Status: todo
* Issue / PR: #28
* Depends on: T-0021, T-0004
* Spec: §1, §10 Phase 6
* Acceptance criteria: Signed Android and iOS builds from CI, store listings in FR and EN. Blocked on the pricing and monetization decision (spec §1).

## Discovered

### T-0003 · Away members: dismiss their open tasks when marked away

* Status: done
* Issue / PR: —
* Depends on: T-0007, T-0008
* Spec: §2 Away, §3.3 Dismissal and Away
* Acceptance criteria: When an admin marks a member away in households-service, tasks-service closes that member's open tasks. Changed from the original issue (reassign) by a product decision: open tasks are dismissed with reason `assignee_away`, and later assignment ignores away members.
* Summary: tasks-service V4 adds `assignee_away` to the dismissal-reason CHECK; new admin-only `POST …/tasks/dismiss-away/{userId}` dismisses the member's open tasks (`dismissed_by` is the admin). `reassign-away` stays, marked deprecated in code and OpenAPI. `MembershipService.setAway` calls the new endpoint through `AwayTaskDismissal` inside its own transaction with the admin's token; a tasks-service failure returns 503 and rolls the away change back. Spec §3.3 and AGENTS §7 updated.
* Decisions and deviations: Failure policy (fail, no retry/outbox) and the dismiss-instead-of-reassign rule come from the product owner. A future-dated `away_from` is not dismissed when it begins (T-0012). No notification is sent for the dismissal (the spec does not define one). If the households commit fails after tasks were dismissed, the tasks stay dismissed; the window is small and accepted for now.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (tasks `TaskAwayDismissalTest`, V4 applied from scratch on Postgres; households `AwayTaskDismissalTest` incl. rollback and 503). Live on real Keycloak 26 + Postgres 16 with both services in dev mode: non-admin got 403 and nothing changed; admin marked a member away, both open tasks became `dismissed/assignee_away`; with tasks-service stopped the call returned 503 and `away_from` stayed null. The live run needed `-Dquarkus.oidc.token.principal-claim=sub` (T-0013) and a direct SQL membership insert (T-0014). `make` is not installed, so `make check`, spotless/checkstyle, the dependency audit, Flutter checks and e2e were not run.
* Follow-ups: T-0012, T-0013, T-0014.

### T-0004 · OpenShift / CRC deploy manifests for microservices

* Status: blocked (no OpenShift cluster available; blocker is environmental, decided by the product owner on 2026-10-13. Local runs use Podman Compose: ADR 0003, AGENTS §6.1)
* Issue / PR: #1
* Depends on: T-0001
* Spec: §7, ADR 0003
* Acceptance criteria: Deployments, Routes, ConfigMaps/Secrets, health probes, and migration Jobs for each service on OpenShift Local or a cluster.

### T-0005 · Generate OpenAPI from code and guard it against drift

* Status: done
* Issue / PR: #2
* Depends on: T-0001
* Spec: AGENTS §5.1 (API contract), ADR 0006 / 0007 / 0015
* Acceptance criteria: Changed from the original issue (OWASP audit and generated-client guard) by the product owner: the OpenAPI documents are generated from annotations in the Java code instead of being written by hand, and the build fails when the committed documents differ from what the services serve. The OWASP audit moves to T-0038 (parked); the generated-client guard stays with T-0020.
* Summary: All 45 operations of the five services carry `@Operation` (stable `operationId`), `@APIResponse` (success, error and 401/403/404 codes with the `ErrorResponse` body) and `@Tag`; a bearer scheme is configured once in `common-domain`. Untyped `Map` answers became records (`ServiceInfo`, `DismissedCount`, `ReassignedCount`, `CelebrationSeen`) with identical JSON. `documentation/api/<service>-openapi.yaml` are generated and committed; the hand-written `openapi.yaml`, `tasks-`, `scoring-` and `households-internal-` files are removed (internal operations are tagged `internal` in the households document). Each service has `OpenApiContractTest` (shared `OpenApiContract` helper in the `common-domain` test-jar). `make openapi` regenerates. ADR 0015.
* Decisions and deviations: Contract is per service until T-0019 merges it into `documentation/api/openapi.yaml`, so AGENTS §5.1 and ADR 0006/0007 still name a file that does not exist yet. Comparison is on parsed trees (formatting never fails it); regenerate with `make openapi`. Operations with any explicit `@APIResponse` must declare their 2xx too (SmallRye drops the default). `LocalTime` fields carry an explicit string schema because the default example is read as a base-60 number by YAML parsers. `make` runs need `jbang` on `PATH` so the Makefile finds JDK 21.
* Verification: `make test-backend` (Spotless, Checkstyle, all tests, coverage floors, contract tests) passes on JDK 21. Negative checks run and reverted: adding an undocumented field to a response makes `OpenApiContractTest` fail with "no longer matches"; deleting a committed file fails with "does not exist"; regenerating twice produced identical files. The first households run exposed a parse problem that generation alone hid (fixed). Flutter, e2e and CI were not run.
* Follow-ups: T-0038 (OWASP audit, parked), T-0039 (check real answers against the contract), T-0019 (aggregate), T-0020 (Dart client + `make test-guard`).

### T-0006 · Keycloak sign-in in Flutter (Android and web) and e2e sign-in

* Status: done
* Issue / PR: #3 / #64
* Depends on: T-0002, T-0020
* Spec: §2, §9, AGENTS §6.2
* Acceptance criteria: App authenticates via Keycloak (PKCE); e2e covers sign-in against the real stack. Changed by the product owner on 2026-10-14: the same sign-in must work on web and Android, so T-0069 is merged into this task and `oidc` replaces `flutter_appauth`.
* Summary: `AuthService` seam (`lib/auth/`) with `OidcAuthService` (`oidc` + `oidc_default_store`, code flow with PKCE, refresh by the library) and a fake for tests. `main.dart` runs the real app when `API_BASE_URL` and `KEYCLOAK_ISSUER` are set (demo mode otherwise; the fixed `ACCESS_TOKEN` define is gone). The repositories take `accessToken` as a supplier, so refreshed tokens are used. `BetterHomeApp` restores a session or shows `SignInScreen` (FR/EN), then loads the profile (`GET /v1/me`, `PUT /v1/me` from the claims on 404 only) and shows households with a sign-out action. Platform setup: `web/redirect.html`, Android `oidcRedirectScheme` placeholder and `FlutterFragmentActivity`, realm redirect URIs and web origin fixed to `localhost:8090`. `make e2e` (web) first runs `app/test_driver/web_sign_in.dart`, which signs in through Keycloak's login page in headless Chrome with WebDriver, then the repository journey.
* Decisions and deviations: ADR 0020. T-0069 dismissed (merged here). Web tokens live in `localStorage` through the library's default store, unlike the in-memory storage first suggested (T-0072). Profile sync only on first sign-in so `PUT /v1/me` never overwrites saved settings. The WebDriver script is Dart (`webdriver` dev dependency) to avoid another language. The realm no longer allows `http://localhost:*`: Keycloak wildcards only work at the end of a URI. The repository journey still uses a token fetched by `tooling/e2e.sh`.
* Verification: JDK 21, Podman, Flutter 3.47.7. `make test-docs`, `make test-app` (format, analyze, tests incl. claims, flow in EN/FR, sign-in goldens and accessibility checks), `make test-guard`; cold `make down` then `make e2e`: web sign-in journey (Keycloak login, households, sign out) and repository journey pass; a wrong password fails the journey. `flutter build web` and `flutter build apk --debug` succeed and the merged Android manifest declares the `com.betterhome.betterhome` redirect. NOT verified: sign-in on Android (emulator crash, T-0045), CI run (this PR), backend tests (no backend change).
* Follow-ups: T-0072 (web token storage), T-0045 (Android run), T-0021 (more journeys after sign-in, CI job).

### T-0008 · HTTP MembershipGateway from tasks-service to households-service

* Status: done
* Issue / PR: —
* Depends on: T-0007
* Spec: §7 service boundaries
* Acceptance criteria: Replace in-memory membership directory with token-propagating REST client; keep test double for Quarkus tests.
* Summary: households-service exposes read-only `GET /v1/internal/households/{id}/members` and `/settings` for the `service` realm role. tasks-service's `HttpMembershipGateway` calls them through `HouseholdsClient` with its own client-credentials token (`quarkus-oidc-client`), for request handlers and background jobs alike. `InMemoryMembershipGateway` moved to `src/test` as a CDI alternative. Households unreachable maps to 503 (`TaskException.ServiceUnavailable`). New Keycloak client `betterhome-tasks-service` and realm role `service`; ADR 0014; `documentation/api/households-internal-openapi.yaml`.
* Decisions and deviations: Deviates from "token-propagating": forwarding the user's token cannot serve scheduler jobs, so one service-account token is used everywhere (ADR 0014); no `/members/me` endpoint was added. Tasks verifies the user's token, then asks households whether that subject is a member. The service role can read any household, so only trusted services may hold it. Realm secret is the same local-dev placeholder as `betterhome-api`; real secrets come from `OIDC_SERVICE_CLIENT_SECRET`. The fake households server in tests returns hand-written JSON; the contract is checked against the real service only by the live run below until T-0005 adds drift checks.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (households 20 tests incl. `InternalHouseholdResourceTest` role matrix; tasks 28 tests incl. `HttpMembershipGatewayTest`). Live: real Keycloak 26 realm import yields a service token with `realm_access.roles=[service]`; households-service in dev mode answers internal endpoints 401 (no token) / 403 (user token) / 200 / 404; tasks-service in dev mode created and listed a template for the real admin and returned 403 for a service account and an unknown household. The live run needed `-Dquarkus.oidc.token.principal-claim=sub` (see T-0013). `make` is not installed, so `make check`, Flutter checks and e2e were not run.
* Follow-ups: T-0013, T-0010 (scoring reuses the pattern), compose does not start the services yet (T-0004).

### T-0010 · HTTP PointsLedgerClient and scoring MembershipGateway

* Status: done
* Issue / PR: #4 / #34
* Depends on: T-0009
* Spec: §7 service boundaries, §3.4
* Summary: tasks-service writes the ledger through `HttpPointsLedgerClient` (REST to scoring award/reverse with its service token); scoring-service resolves membership through `HttpMembershipGateway` (households internal members endpoint with its own service token). The in-memory doubles moved to `src/test` as `@Alternative @Priority(1)` beans. New Keycloak client `betterhome-scoring-service` (service role) in the realm export; secret via `OIDC_SERVICE_CLIENT_SECRET`, local-dev placeholder only in `%dev`/realm. Scoring contract regenerated (`adminUserId`, 503); scoring coverage floor raised 0.62 to 0.75.
* Decisions and deviations: Award and reverse now require the `service` role (ADR 0014 addendum); household admins and members get 403 there, and award no longer checks membership because tasks authorizes the user first. Reverse carries `adminUserId` (the caller is no longer the admin) and scoring verifies via households that it is an active admin. Any scoring failure maps to `TaskException.ServiceUnavailable` (503), or Conflict on a 409; the call is the last step of the task transaction, so a failed award rolls the completion back and a failed reversal leaves the task done. Known gap: scoring commits before tasks commits, so a failed local commit leaves points without a done task (T-0040).
* Verification: `make test-backend` (all services green, JaCoCo floors met, spotless and checkstyle clean); `make openapi` regenerated scoring only. Live run with real Keycloak 26, Postgres 16 and households/tasks/scoring in dev mode: bob completes a task and the real scoreboard shows 5 points; a user token calling award directly gets 403 (also for the admin); alice reverts it and the scoreboard returns to 0; with scoring stopped, completion answers 503 `service_unavailable` and the task stays open with no done tasks. Not run: Flutter, `make e2e`, households-down live case (covered by tests only).
* Follow-ups: T-0040.

### T-0012 · Dismiss open tasks when a future-dated away period starts

* Status: in-review
* Issue / PR: #5 / #59
* Depends on: T-0003
* Spec: §2 Away, §3.3 Away
* Acceptance criteria: A member marked away with a future `away_from` has their open tasks dismissed (`assignee_away`) when that instant arrives. Needs a households scheduler (claims due rows with `FOR UPDATE SKIP LOCKED`, one transaction per job) and a way to call tasks-service without a user token, which means a write-capable service role that ADR 0014 does not grant yet; decide that first. The job must also mark what it has handled so a restart does not repeat it.
* Summary: households-service Flyway V4 adds `membership.away_tasks_dismissed_at`. `AwayStartScheduler` (every 30 s) runs `AwayStartDismissal`, which claims one due membership at a time (`FOR UPDATE SKIP LOCKED`, own transaction), calls tasks-service with households' own client-credentials token and sets the marker. tasks-service gets `POST /v1/internal/households/{id}/tasks/dismiss-away/{userId}?dismissedBy=` (`service` role). Setting away again resets the marker; a request that dismisses immediately sets it, so the job never repeats it. New Keycloak client `betterhome-households-service`, compose env, spec §3.3 and data model, OpenAPI for both services regenerated.
* Decisions and deviations: ADR 0014 addendum: reuse the existing `service` role rather than add a write role (all service accounts are equally trusted); the endpoint trusts `dismissedBy` (= `away_set_by`). Added extensions `quarkus-oidc-client`, `quarkus-rest-client-oidc-filter` (attaches the service token, keeps the job testable without a token endpoint) and `quarkus-scheduler` to households. A failed call ends the run and leaves the period due (retry in 30 s); a persistently failing head row blocks later rows until it succeeds. Periods that were cleared, ended (`away_until` past) or whose member left are never dismissed. No notification is sent (spec defines none).
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (spotless, checkstyle, all five services, Postgres Dev Services): re-run after merging master (tasks and households, with their dependencies): all green, 121 tasks tests, none skipped. CI exposed one gap, fixed: the 400 of the new endpoint was missing from the OpenAPI document (the contract test refuses undocumented answers). New tests: households `FutureAwayDismissalTest` (due/not due, once only, reschedule, cleared, ended, left, unreachable and refused tasks-service, two-replica SKIP LOCKED with a blocked first run, TestClock), tasks `InternalAwayDismissalTest` (service allowed, admin/member 403, anonymous 401, missing `dismissedBy` 400). Not run: `make` targets (make not installed), the real Keycloak/token path for the new client (the running Podman stack was left untouched and does not have the new realm client), live scheduler against the compose stack, dependency audit, Flutter checks, e2e.
* Follow-ups: the realm export must be re-imported (`make down`/`up`) before households can fetch its token locally; households-openapi.yaml lists REST client interfaces as endpoints (existing `TasksClient` and now `TasksInternalClient`), suggest an issue to exclude clients from OpenAPI scanning; an e2e journey for a future-dated away period needs the controllable clock in households.

### T-0013 · Services reject every real Keycloak user: principal is not the `sub` UUID

* Status: done
* Issue / PR: #6
* Depends on: T-0001
* Spec: §2, §9 (auth), AGENTS §3 (Auth)
* Acceptance criteria: `OidcAuthVerifier` expects the principal name to be the Keycloak `sub` UUID, but quarkus-oidc defaults to `preferred_username`, so with a real token every service answers 401 "Authentication required". Set `quarkus.oidc.token.principal-claim=sub` in each service (found during T-0008; reproduced with the demo user from `deploy/keycloak/README.md` and fixed at runtime only), and add a test that fails without it.
* Summary: `common-domain/src/main/resources/META-INF/microprofile-config.properties` sets `quarkus.oidc.token.principal-claim=sub`, so all five services pick it up from the module that owns `OidcAuthVerifier`. New shared test fixture `RealOidcTestResource` (common-domain test-jar) enables token validation with a generated RSA key and signs Keycloak-shaped tokens; each service has `RealTokenAuthTest` calling `/v1/meta` with a token whose `sub` is a UUID and `preferred_username` is `demo`.
* Decisions and deviations: One property in `common-domain` instead of five copies (deviation from the issue text); service `application.properties` can still override it. Root `pom.xml` manages the `common-domain` test-jar, which each service depends on in test scope. The test failed before the fix in households-service (200 with an empty `authSubject`); the other four share the same code path and were run only with the fix.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (all services pass). Live on real Keycloak 26 + Postgres 16 with households and tasks in dev mode and no runtime override: demo user's `/v1/meta` returned the Keycloak `sub`, profile sync 200, household create, template create 201, no token 401, unknown household 403. `make` checks beyond `verify` (spotless, checkstyle, audit), Flutter and e2e were not run.
* Follow-ups: T-0036.

### T-0014 · Invitation endpoints return 404 on a running server

* Status: done
* Issue / PR: #7
* Depends on: T-0002
* Spec: §2 (invitations)
* Acceptance criteria: `POST/GET /v1/households/{id}/invitations` answer 404 "Resource Not Found" when the service runs, although they are listed in the route table and the service-level tests pass. `InvitationResource` is rooted at `@Path("/v1")` and appears to lose to `HouseholdResource` at `/v1/households`. Add an HTTP-level test that fails today (create then accept an invitation through REST) and fix the routing.
* Summary: `InvitationResource` is now rooted at `/v1/households/{householdId}/invitations` (create, list); accept moved to the new `InvitationAcceptResource` at `/v1/invitations/{token}/accept`. URLs and OpenAPI are unchanged. `InvitationHttpTest` drives the flow over HTTP with real signed tokens (T-0013 fixture): invite, list, accept, members, plus 403 for an outsider and 401 without a token.
* Decisions and deviations: Confirmed cause: a class path of `/v1` is out-ranked by the longer `/v1/households` class, so its methods were never reached. No other resource in the service is rooted at a bare `/v1`.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (both new tests failed with 404 before the change). Live on real Keycloak 26 + Postgres 16 with households in dev mode: admin created an invitation (201) and listed it, a member's invite attempt got 403, the invitee accepted (200), members were admin + member. `make` checks beyond `verify`, Flutter and e2e were not run.
* Follow-ups: none.

### T-0036 · Real Keycloak roles are not mapped in tasks, scoring, lists and notifications

* Status: dismissed (premise was wrong: Quarkus OIDC already reads Keycloak's `realm_access.roles` by default)
* Issue / PR: #29
* Depends on: T-0013
* Spec: §2, AGENTS §8
* Acceptance criteria: Only households-service sets `quarkus.oidc.roles.role-claim-path=realm_access/roles`. In the other four services `/v1/meta` is `@RolesAllowed({"member","admin"})`, so a real Keycloak token (roles under `realm_access.roles`) would get 403 there. Set the claim path in one shared place next to the verifier config (T-0013) or drop the role requirement from `/v1/meta`; add a `RealTokenAuthTest` assertion that fails first.
* Summary: The suspected 403 does not happen. `RealOidcTestResource` tokens now carry roles only under `realm_access.roles`, as Keycloak issues them (the `groups` claim was removed), and `RealTokenAuthTest` still returns 200 in all five services; households also passes with its own `role-claim-path` removed (temporary experiment, reverted).
* Decisions and deviations: No production change. The stricter fixture stays, so the five tests now prove role mapping from `realm_access.roles`. The households `role-claim-path` line is redundant but harmless and was left alone (not made obsolete by this task); drop it in a later cleanup if desired.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (all services pass). Gotcha: a stale `common-domain` test-jar in `~/.m2` can hide fixture changes; use `verify` (reactor jar), not `test`, when changing the fixture.
* Follow-ups: none.

### T-0037 · Unit tests for common-domain seams

* Status: done
* Issue / PR: #30 / #39
* Depends on: T-0017
* Spec: AGENTS §5.1, §5.3
* Acceptance criteria: common-domain line coverage is 9% (only `SystemClock`); `OidcAuthVerifier`, `NoOpPushSender` and the other seams are exercised only through the services' tests. Add direct unit tests for them and raise the `jacoco.line.minimum` floor in `common-domain/pom.xml`.
* Summary: Plain JUnit 5 tests now cover every class in common-domain main: `OidcAuthVerifier` (real `QuarkusSecurityIdentity`: valid UUID, anonymous, null identity, null/blank principal name, non-UUID name), `NoOpPushSender` (logs only type and user at FINE, never body or payload; silent at INFO), the `PushMessage` record, and `SystemClock` monotonicity. Line coverage 2/21 (9%) -> 21/21 (100%), all 8 branches; `jacoco.line.minimum` 0.09 -> 0.99.
* Decisions and deviations: No production change and no Quarkus test infrastructure or mocks. The floor is 0.99, just below the measured 1.00, as the task asked.
* Verification: `make test-backend` on JDK 21 with Podman passes (common-domain 11 tests, all services green, floors met). Flutter, e2e and CI were not run.
* Follow-ups: none.

### T-0038 · OWASP Dependency-Check and `make test-policy`

* Status: blocked (parked by the product owner: "we'll add this later"; needs a free NVD API key, kept as a CI secret and in `NVD_API_KEY` locally)
* Issue / PR: #31
* Depends on: T-0017
* Spec: AGENTS §5.3, §8
* Acceptance criteria: OWASP Dependency-Check runs inside `make test-backend` and `make test-policy`, reading the NVD key from `NVD_API_KEY`, and fails (not passes) when it cannot update or reach its database or when the key is missing. Covers the Maven dependencies now; Dart dependencies follow once Flutter is installed (T-0015).

### T-0039 · Check real HTTP responses against the generated contract

* Status: done
* Issue / PR: #32 / 42
* Depends on: T-0005
* Spec: AGENTS §5.1 (API contract)
* Acceptance criteria: Quarkus tests validate every real response (status, headers, body) against `documentation/api/<service>-openapi.yaml` with a request/response validator and fail when an answer has a field or status the document does not declare; additional properties are forbidden in schemas. T-0005 keeps the document equal to the code; this keeps the answers equal to the document.

### T-0040 · Make ledger awards idempotent per task

* Status: done
* Issue / PR: #33 / #58
* Depends on: T-0010
* Spec: AGENTS §7 (points ledger, completion)
* Acceptance criteria: Awarding the same task and reason twice appends one row (unique constraint plus idempotent endpoint), or tasks writes awards through an outbox in the same transaction. A commit failure in tasks after scoring committed can no longer leave points for an open task or double-award on retry. Tests cover the retry.
* Summary: tasks-service numbers each completion of a task (`task.completion_no`, tasks V5, incremented in the completing transaction) and sends it as `completionNo` on `POST .../points/award`. scoring-service V3 adds `point_transaction.completion_no` with a partial unique index on `(task_id, completion_no)`; the insert is `ON CONFLICT DO NOTHING`, an identical repeat returns the stored row, a differing one answers 409. `documentation/api/scoring-openapi.yaml` regenerated.
* Decisions and deviations: The ticket's unique `(task, reason)` would block a legitimate second award when a reverted recurrence task reopens and is completed again, so the key is the completion number (chosen by the product owner on 2026-10-14). Not done: the outbox option. Residual: if scoring commits and tasks then fails and nobody retries, the award stays for a task that is still open until the retry; a retry never double-awards. After T-0039 the award endpoint also documents its 409, and `ScoringHttpTest` sends `completionNo`.
* Verification: JDK 21, Podman, `./mvnw verify -pl services/scoring-service,services/tasks-service -am` after merging master (scoring 32 tests, tasks 49 tests incl. the now clock-controlled reminder test; coverage floors met). The `check` CI job is the evidence for `make check`. NOT verified: app, e2e, the running stack (not rebuilt).
* Follow-ups: none.

### T-0046 · Build the five container images in make check and CI

* Status: todo
* Issue / PR: #37
* Depends on: T-0016, T-0018
* Spec: AGENTS §5.3
* Acceptance criteria: `make check` / CI builds the five images from the packaged jars and runs `make smoke`; the Dockerfiles' `EXPOSE 8080` matches the real service ports (8081-8085).

### T-0045 · Headless Android emulator crashes on the development VM

* Status: todo
* Issue / PR: #35
* Depends on: T-0015
* Spec: AGENTS §6.2
* Acceptance criteria: `tooling/start-emulator.sh` boots the AVD to `sys.boot_completed=1` on the dev VM, or the e2e job is moved to CI with a documented reason, and `make doctor` gains a boot check. Observed: SIGSEGV in `qemu-system-x86_64-headless` about 25-30 s after start, when the guest `media` service starts (guest kernel boots fine); emulator 37.2.12, Android 35 google_apis x86_64, AMD Ryzen 7 5800X VM on Fedora 44. Same result with `-gpu swiftshader_indirect`, `-gpu guest`, `-feature -Vulkan`, `-accel off`, cameras off and `-feature -HardwareDecoder`. Not yet tried: another emulator build, another system image (API 34, non-google_apis), a gdb backtrace, an AVD without audio hardware.

* Summary: `ContractValidation` (common-domain test-jar) validates each REST-assured answer with the Atlassian `openapi-request-validator` against the committed contract. Every service installs it for all its tests through a `QuarkusTestBeforeEachCallback` (`ContractValidationCallback`), so existing and future HTTP tests are checked without per-test code (Quarkus `/q/` endpoints excluded). Negative tests (`lists-service` `ContractValidationTest`) show an undocumented field, a wrong type and an undocumented status each fail against tampered copies of the contract. New HTTP tests: `ScoringHttpTest`, `TasksHttpTest` (success and 400/401/403/404/409 answers), plus a households 400 case.
* Decisions and deviations: new test dependency `com.atlassian.oai:openapi-request-validator-restassured` 3.0.0 (Apache-2.0, maintained by Atlassian, builds on swagger-parser; it reads the OpenAPI 3.1 documents SmallRye generates, verified by the green run), see ADR 0016. Only answers are judged, not requests, because tests send invalid requests on purpose and the validator cannot tell request schema errors from response ones by level (follow-up T-0041). Unknown fields are rejected by closing every object schema in memory (`additionalProperties: false`) instead of changing the committed documents, so generated clients stay tolerant. Real mismatches found and fixed: (1) `reminderTime` was `format: time` (RFC 3339 full-time with offset) but the API returns a local `08:00:00`; now `format: partial-time` plus a pattern, documents regenerated; (2) nullable fields were serialized as `null` while documented as plain types; services now omit nulls (`quarkus.jackson.serialization-inclusion=non-null`); (3) bean validation failures answered the framework violation report, not the documented `ErrorResponse`; each service with `@Valid` now has a `ConstraintViolationMapper`.
* Verification: `make test-backend` (Spotless, Checkstyle, all unit and integration tests on real PostgreSQL, JaCoCo floors, OpenAPI contract tests) passed. Not run: Flutter, e2e, `make check`. No live stack run: the behavior changes are covered by `@QuarkusTest` HTTP calls.
* Follow-ups: T-0041 (validate requests), T-0042 (HTTP tests for remaining endpoints).

### T-0041 · Validate test requests against the contract

* Status: todo
* Issue / PR: #40
* Depends on: T-0039
* Spec: AGENTS §5.1 (API contract)
* Acceptance criteria: Requests that tests send as valid are validated against the request schemas of the contract, while tests that send invalid requests on purpose are not rejected by the filter.

### T-0042 · HTTP tests for endpoints without one

* Status: todo
* Issue / PR: #41
* Depends on: T-0039
* Spec: AGENTS §5.1 (API contract)
* Acceptance criteria: Every endpoint of every service has at least one REST-assured call (success and error) so its answers are checked against the contract.

### T-0053 · Require the CI `check` job on master

* Status: todo
* Issue / PR: #49
* Depends on: T-0018
* Spec: AGENTS §6.2
* Acceptance criteria: Branch protection on `master` requires the `check` job from `.github/workflows/check.yml` to pass before merge. Repository setting (admin), no code change.

### T-0047 · `reminderEnqueuesWhenDue` fails before 08:00 UTC

* Status: done
* Issue / PR: — (suggested: "Test depends on the wall clock") / #60
* Depends on: —
* Spec: AGENTS §5.1 (control time with the clock)
* Acceptance criteria: `TaskPhase4AutomationTest.reminderEnqueuesWhenDue` passes at any time of day by using a fake `Clock`. Observed at 06:09 UTC: the test set `dueAt` to `Instant.now()+2h` and the household reminder time is 08:00 UTC, so no reminder was due yet.
* Summary: tasks-service tests get a `TestClock` (`@Alternative`, follows system time until a test fixes it). The test fixes it at 2026-03-10T12:00Z and derives the recurrence start and due date from it.
* Decisions and deviations: Only this test fixes the clock, so other tests keep system time and are unchanged.
* Verification: JDK 21, `./mvnw verify -pl services/tasks-service -am` (42 tests pass, coverage floor met) at 06:44 UTC, a time at which the test failed before. Not run: `make check`, app, e2e.
* Follow-ups: none.

### T-0057 · Render readable text and icons in app golden images

* Status: in-review
* Issue / PR: #44 / (pull request to follow)
* Depends on: T-0022
* Spec: AGENTS §5.2
* Acceptance criteria: Goldens show real text and icons by loading a bundled test font in `app/test/support/screen_harness.dart`; regenerated on Linux (ADR 0012).
* Summary: `pumpScreen(realFonts: true)` loads every font in the app's `FontManifest.json` (Figtree, Bricolage Grotesque, Material and Cupertino icons) with `FontLoader`; the three golden tests (`screens_baseline_test`, `widgets_test`, `design_system_test`) set it. All goldens regenerated on Linux.
* Decisions and deviations: No binary added and no Roboto: the theme uses Figtree and Bricolage Grotesque (OFL, licenses already in `app/assets/fonts`, T-0079) and Flutter bundles Material Icons through `uses-material-design`, so the goldens show the fonts the app really ships. Fonts cannot be unloaded and `textContrastGuideline` samples anti-aliased pixels, so it reports false failures (for example 1.06:1) on real glyphs; real fonts are therefore opt-in and each file declares its golden tests after its accessibility tests (a misordering fails loudly, never silently passes). Emoji in chore titles still render as empty boxes (no emoji font bundled).
* Verification: `make client`, `make update-goldens`, then `flutter test` (441 pass), `flutter analyze` and `dart format --set-exit-if-changed .` clean, on Linux. Not run: the rest of `make check`, e2e.
* Follow-ups: Optionally bundle an emoji font for the golden tests (large binary, product owner's call); a contrast check that does not depend on glyph pixels.

### T-0058 · Externalize remaining hard-coded strings and raw ids in app screens

* Status: todo
* Issue / PR: #45
* Depends on: T-0022
* Spec: AGENTS §9
* Acceptance criteria: Chores status and points labels, the default template title and member labels (currently raw user ids) come from ARB keys or the members API in FR and EN; goldens regenerated.

### T-0059 · Golden and accessibility coverage for dialogs and non-admin views

* Status: in-review
* Issue / PR: #46 / (pull request to follow; stacked on #107, T-0057)
* Depends on: T-0022, T-0057
* Spec: AGENTS §5.2
* Acceptance criteria: Scenarios for the non-admin household detail and chores views and for every dialog and snackbar, with goldens and accessibility checks in FR and EN.
* Summary: `screens_baseline_test.dart` gains 13 scenarios (accessibility, 200% text scale and golden, FR and EN): household detail and chores as a plain member (a test double lists an admin plus the signed-in member, since `FakeHouseholdsRepository` only knows its own user), the invite, invite-created, accept-invitation, dismiss-confirmation and revert dialogs (opened through the UI, fields filled), and the toasts (spawned count, recurrence saved, quick-log with undo, error). A scenario can now run an `act` step after the screen is pumped. 32 new goldens, no existing golden changed.
* Decisions and deviations: Create-template and make-recurring are full screens, not dialogs, and already have the `template_form` and `recurring_form` scenarios, so none was added. The new checks found two real defects in production code, fixed minimally: `AlertDialog` buttons in household detail and chores had 4.26:1 contrast on the default tinted dialog surface (they now use `AppTokens.card`, as a white dialog gives enough contrast), and the revert dialog overflowed by 14 px at 200% text (its content now scrolls). A global `dialogTheme` would have been simpler but also changes the month-recap dialog, hence the `leaderboard_recap` goldens, so it was not used. Toast scenarios advance a fixed 500 ms so the countdown bar is deterministic.
* Verification: `make client`, `make update-goldens`, then `flutter test`, `flutter analyze` and `dart format --set-exit-if-changed .` in `app/` on Linux. Not run: the rest of `make check`, e2e.
* Follow-ups: see Discovered (dialog contrast in lists and the text prompt).

### T-0061 · Spec: who may reset a list, and archived-list rules

* Status: todo
* Issue / PR: #50
* Depends on: T-0023
* Spec: §2, §4
* Acceptance criteria: Spec states who can bulk reset (T-0023 allows any active member), that items of an archived list are frozen (409), and that re-checking is a no-op; code follows if the decision differs.

### T-0062 · tasks-service: body-less POST actions answer 415 without a Content-Type

* Status: in-review
* Issue / PR: #51 / —
* Depends on: —
* Spec: AGENTS §3 (API style)
* Acceptance criteria: `@Consumes` moves from class level to body-bearing methods in tasks-service (and any other service with the same pattern); a test posts an action without Content-Type and gets 2xx.
* Summary: `@Consumes(JSON)` now sits only on body-bearing methods in tasks (`TaskResource`, `TemplateResource`), households (`MembershipResource`; `InvitationAcceptResource` has none left) and scoring (`ScoreboardResource`). Tests post `complete`, `dismiss`, `reassign`, `dismiss-away`, `reassign-away`, `archive`, invitation accept, `leave` and `celebrate` with no Content-Type and expect 2xx (the tasks test failed with 415 before the change).
* Decisions and deviations: lists and notifications have no body-less POST; `RecurrenceResource`, `PreferenceResource` and the other resources only have body-bearing writes, so they keep the class-level annotation.
* Verification (local, GitHub Actions minutes exhausted; local PostgreSQL 16, no Docker): `make test-docs` OK; `spotless:check checkstyle:check` OK; `mvn verify` per service with coverage checks: households 57, scoring 86, lists 68, notifications 53 tests green; tasks 117 tests with 1 failure that also fails without this change (see Follow-ups). Not run: `make e2e`, `make test-app` (no Podman, Flutter or emulator here), so this is not `done`.
* Follow-ups: `RruleEnginePropertiesTest.aMonthlyRuleOnADayThatSomeMonthsLackSkipsThoseMonthsInsteadOfClamping` fails deterministically on the parent commit too (expected 29, was 30), so `make check` is red on tasks-service independently of T-0062; needs its own task and fix.

### T-0063 · lists-service: anonymize user ids on account deletion

* Status: todo
* Issue / PR: #52
* Depends on: T-0023
* Spec: AGENTS §8
* Acceptance criteria: Internal service-role endpoint anonymizes `list.created_by` and `item.creator/completer/deleted_by` for a user; covered once the account-deletion flow exists.

### T-0065 · tasks-service: reminder test depends on the wall-clock time of day

* Status: dismissed (duplicate of T-0047, fixed by #60: the test is driven by a fake Clock)
* Issue / PR: #54
* Depends on: —
* Spec: AGENTS §5.1 (control time with the clock)
* Acceptance criteria: `TaskPhase4AutomationTest.reminderEnqueuesWhenDue` sets `dueAt` from `Instant.now()` and fails when run before the household reminder time of day. Drive it with the fake Clock so it passes at any hour.

* Note: no longer blocks `make e2e`, which runs on the web target by default (ADR 0018); it still blocks the `android` target.

### T-0069 · Web sign-in for the app

* Status: dismissed (merged into T-0006 by the product owner on 2026-10-14: `oidc` signs in on web and Android)
* Issue / PR: #56
* Depends on: T-0006
* Spec: §2, §9, AGENTS §6.2
* Acceptance criteria: decide and implement how the web build signs in to Keycloak (`flutter_appauth` has no web support), or record that web e2e stays token-injected. Needs a product decision first.

### T-0070 · Faster CI: run the gates as parallel jobs

* Status: done
* Issue / PR: — (suggested: "CI takes too long to go green") / #61
* Depends on: T-0018
* Spec: AGENTS §6.2, ADR 0019
* Acceptance criteria: A green `check` on a pull request arrives noticeably sooner than the 5 minutes of the single `make check` job, with the same gates, and a failing gate still fails `check`.
* Summary: Measured one run (run 38530080319): `make check` 268 s, of which the five services built in sequence took 3m47, plus 39 s of Flutter setup. The workflow now runs `docs`, one `backend` job per service (`make test-backend SERVICE=<name>`, new optional variable) and `app` in parallel, joined by a `check` job that fails unless all succeeded.
* Decisions and deviations: AGENTS §6.2 says CI runs `make check`; CI now runs the same make targets split across jobs, and `make check` is unchanged locally (ADR 0019). The service matrix is read from `backend/services` so a new service cannot silently go untested. Flutter is installed only in the app job. Path filtering to skip jobs was not added: the wall time is set by the slowest job, so it would add logic without saving wait.
* Verification: see the PR description for the measured time of the new workflow against the 5 minute baseline. Not run: `make check` locally as a whole.
* Follow-ups: when T-0053 is done, require the `check` job; add jobs here when T-0021 (e2e), T-0046 (images) and T-0038 (dependency audit) land.

### T-0071 · Contract: mark response fields as required

* Status: todo
* Issue / PR: — (suggested: "OpenAPI response fields are all optional")
* Depends on: T-0019
* Spec: AGENTS §5.1 (API contract), ADR 0006
* Acceptance criteria: Response records of every service declare their always-present fields as required in the generated OpenAPI (for example `@Schema(required = true)` or `@NotNull`), so the generated Dart models are non-nullable and `need` in `app/lib/data/api_mappers.dart` can go. Contract and committed documents regenerated; the response validation (T-0039) keeps passing.

### T-0072 · Decide where the web build keeps its tokens

* Status: todo
* Issue / PR: — (suggested: "Web tokens are stored in localStorage")
* Depends on: T-0006
* Spec: §9, AGENTS §8
* Acceptance criteria: Decide between the library's default (browser `localStorage`, session survives a reload, readable by any script injected into the page) and an in-memory store (needs a re-login on reload, and the sign-in must then avoid a full-page redirect); implement the choice and record it in ADR 0020.

### T-0074 · e2e: the sign-in journey timed out once while the app was starting

* Status: dismissed (cause found in T-0073: the dev server answered `index.html` while the app compiled and the readiness check accepted it; the check now needs a JavaScript content type. Reopen if it times out again)
* Issue / PR: — (suggested: "web sign-in e2e is flaky on a cold start")
* Depends on: T-0021
* Spec: AGENTS §6.2
* Acceptance criteria: `app/test_driver/web_sign_in.dart` waits for the app to be ready instead of a fixed 60 s for the accessibility placeholder (observed once on a cold run in a fresh worktree: "Timed out waiting for the app to start"; the rerun passed). Find the cause (release build still being served, or semantics placeholder) and remove the flake.

### T-0075 · App: no way to create an open task or a template, and accepting an invitation needs a household

* Status: todo
* Issue / PR: — (suggested: "Chores screen cannot create tasks or templates")
* Depends on: —
* Spec: §3.1, §8.2
* Acceptance criteria: The e2e creates open tasks through the repository because the UI has no such action, and templates exist only through the quick-log dialog when a household has none. Accepting an invitation is an action inside an existing household's screen, so a new user must create a household first. Needs a product decision on the intended screens (spec §8.2) before any UI change.

### T-0073 · CI job: make e2e on every pull request

* Status: done
* Issue / PR: — (suggested: "Run e2e in CI") / #65, #68
* Depends on: T-0021, T-0018
* Spec: AGENTS §6.2
* Acceptance criteria: `make e2e` (web target: browser sign-in through Keycloak, then the household and chores journeys) runs in CI on every pull request and on `master`, is required by the `check` job, and is as fast as the runner allows.
* Summary: #65 added the `e2e` job to `.github/workflows/check.yml`: it starts the Podman API socket (compose talks to it through `DOCKER_HOST=unix:///tmp/podman.sock`; the runner has rootless Podman), installs the pinned Chrome for Testing with the new `tooling/install-chrome.sh` (also called by `install-dev-tools.sh`), generates the Dart client and runs `make e2e`. The `check` job's `needs` list includes `e2e`, so a failing journey fails `check` (`[ "$r" = success ]` for every result). This PR makes it faster: the Podman socket, the image pulls and the jar build run in the background during the Flutter setup, `make up` skips its own Maven build when `SKIP_PACKAGE=1` (unset by default, local behaviour unchanged), and `e2e.sh` compiles the release app while the stack boots instead of after it.
* Decisions and deviations: Two real defects found through CI. (1) Chrome 155 no longer falls back to software WebGL on a runner without a GPU, so Flutter web drew nothing: a wrapper script passes `--enable-unsafe-swiftshader` on every launch (the WebDriver script and `flutter drive` both use `CHROME_EXECUTABLE`), acceptable for trusted test content. (2) While `flutter run -d web-server` compiles, its server answers every path with `index.html` and HTTP 200, so `e2e.sh` started the sign-in journey against a page without the app (the browser console said `main.dart.js` had MIME type `text/html`); readiness now requires a JavaScript content type. This is the cause of T-0074. Image caching (save/load or a registry cache) was not adopted: measured pulls are small (see below) and restoring a cache of the Keycloak image costs about as much as pulling it. Sharing one Flutter build between the two web journeys is not possible: sign-in needs the release app, `flutter drive` compiles the `integration_test` entry in debug mode. Unverified: Android (no emulator in CI, T-0045).
* Verification: Measured on `ubuntu-24.04` hosted runners (job durations from the Actions API). Job duration of `e2e` before this PR (master code, four runs: 8m56s, 8m52s, 9m17s, 7m01s; mean 8m31s) against after (two runs on this PR: 6m45s, 7m10s; mean 6m58s), about 1m30s less (noisy: shared runners vary by a minute or more). Breakdown of an optimized run: 1m55s of setup before `make e2e` (Flutter 40 s, Chrome 11 s, client 9 s, 26 s waiting for the background jars and pulls), then `make e2e` 5m23s (was 7m07s): stack up and smoke OK at 3m39s (was 4m20s), sign-in journey 26 s after that (was about 1m20s, the release app now compiles while the stack boots), `flutter drive` journeys about 1m15s. Image pulls measured at about 11 s (postgres and keycloak, in parallel) plus 9 s (flyway) plus a few seconds (ubi9 base) per run, and are now overlapped with the Flutter setup, so a cache would save little. The remaining time is the five JVMs starting on a two-core runner (about 1m45s from image build to ready) and the debug compile for `flutter drive`. Not run: Android; the `check` result when `e2e` fails (it requires every needed job to be `success`, and `e2e` is in its `needs`, as read in the workflow; the first runs of #65 showed the job red and `check` red with `results: success success success success failure`).
* Follow-ups: T-0074 is dismissed (the readiness check here explains it); T-0046 images and T-0038 audit are still to add to this workflow; T-0053 (require `check` on `master`).

### T-0076 · Controllable test clock and the e2e journeys that need time

* Status: todo
* Issue / PR: — (suggested: "Controllable clock for e2e") 
* Depends on: T-0021
* Spec: AGENTS §6.2
* Acceptance criteria: A clock that can be moved, exposed only in the test environment of the services (never in production profiles), used by `make e2e` for the journeys that depend on time: recurrence spawn and round-robin assignment, supersede, away reassignment, month-end recap. Also the journeys left from T-0021: leaderboard period views, household switcher with two households, French and English.

### T-0077 · Fake push gateway endpoint for e2e

* Status: todo
* Issue / PR: — (suggested: "Fake push gateway for e2e")
* Depends on: T-0021, T-0027
* Spec: AGENTS §6.2, §3 Push
* Acceptance criteria: The local and e2e stack runs a fake push gateway endpoint that records what notifications-service sends; e2e journeys assert on it (type, language, minimal payload). Needed by the M6 exit.

### T-0078 · `make check` runs the e2e suite

* Status: todo
* Issue / PR: — (suggested: "Include e2e in make check")
* Depends on: T-0073
* Spec: AGENTS §6.1 (`make check` is everything above, as in CI)
* Acceptance criteria: `make check` runs `make e2e` like CI does (or AGENTS §6.1 states why not), without a second stack start when one is already up.

### T-0079 · Bundle the design fonts

* Status: in-review
* Issue / PR: — (suggested: "Use Bricolage Grotesque and Figtree")
* Depends on: T-0024
* Spec: §8, ADR 0021
* Acceptance criteria: Bricolage Grotesque (titles) and Figtree (text) from the design canvas are bundled with the app (their licenses allow it) and set in `AppTypography`; goldens use a readable test font (T-0057) so they show the real look. Decide first: bundle files, or fetch at runtime.
* Decisions and deviations: bundled files (no runtime fetch, works offline): static instances cut from the Google Fonts variable files, Figtree 400–700 and Bricolage Grotesque 600–800 (opsz 36), in `app/assets/fonts` with their OFL licenses. `flutter test` loads them from the pubspec, so goldens show the real fonts. Verified: `flutter analyze`, `flutter test` (goldens regenerated), `dart format`, `make test-docs`. Not run: `make check` and `make e2e`. ADR 0021 deviation "Fonts" no longer applies.

### T-0080 · Restyle the existing screens with the shared widgets

* Status: in-progress
* Issue / PR: — (suggested: "Apply the Claude Design canvas to chores, leaderboard, households")
* Depends on: T-0024
* Spec: §8, ADR 0021
* Acceptance criteria: Households, chores, quick log, leaderboard and household screens follow their boards in the design canvas, using the widgets and tokens of ADR 0021 (add new shared widgets where several screens need them). Goldens regenerated, accessibility baseline and e2e journeys still pass.
* Progress (first slice): colors and radii of the canvas in `AppTokens`; `ChoreCard` (check circle: open, dashed coral when overdue, filled when done); the Chores and My chores screens follow the Chores board (header, All / Mine / Done filters on All chores, "Catch up" and per-day sections, "I just did…" button); the household switcher and the navigation bar are styled after the canvas. The design's tab labels (Chores, Mine, Scores) are not applied: tests and e2e journeys find the tabs by their current names. Second slice: the Leaderboard follows its board (period tabs, podium 2-1-3 with gold ring and a "room for one more" place, shared effort card, hall of winners cards); avatar colors come from the joining order (`memberColor`). The "Podium" heading is gone (the design has none). Tabs keep a 48 px target, so the track is 8 px taller than drawn. Third slice: sign-in has the green hero of the Log in board; buttons (54 px, radius 16) and text fields (white, radius 16, outlined) take the design's look through the theme, so every form gets them; errors use the coral text. The design's in-app email/password forms (Log in, Register) do not exist because sign-in goes through Keycloak. Fourth slice: the household screen follows the Household board (big name with member count and time zone, members card with colored avatars and "Set away" pills, soft green invite row, chore templates as cards, leave as a coral text action). The invite row keeps the tooltip "Invite" that the journeys use. Fifth slice: My chores has the "Hey {name} · {household}" header and the green week card (points, rank, progress, points within reach), fed by the weekly scoreboard. Sixth slice (covers T-0091): "I just did…" opens the Quick log board's bottom sheet (search, two-column template tiles, footnote); same one-tap behavior and 5-second undo; unit tests and the journey tap the tile instead of the dialog option. The undo bar of the board is the existing snackbar. Seventh slice: the week strip of the Chores board (week range, a button per day with dots for done / overdue / upcoming chores; picking a day filters the list, picking it again clears it; the board's "Month" link is not built, there is no month view) and the New recurring chore screen (admin menu "Make recurring" now opens it: chore name, emoji, notes, on-time and late points with the late <= on-time rule, Daily / Weekly / Monthly with interval and weekdays, take turns or one person; it creates the template and its recurrence together, monthly is always the 1st). This replaces the old two-step dialogs, so an existing template can no longer be made recurring from the app (the API still allows it). Eighth slice (review of the first run): the switcher bar is on the Chores tab only; the week strip puts a quick-logged chore on the day it was done; the shared effort bar is visible; every message (undo, errors, confirmations) is the design's toast, a dark rounded box at the top with a countdown bar, instead of a bottom snackbar (`showAppToast`). Ninth slice: creating and editing a chore template is a full screen (`TemplateFormScreen`: icon, name, notes, on-time and late points) built from the same sections as New recurring chore (`ChoreDetailsCard`, `PointsSection`); it replaces the template dialog (household screen, and the first quick-log with no template). The icon is picked from a short list or none, no longer free text. Tenth slice (review of the second run): no title and no menu on the All chores list; the admin actions moved to the household screen's "House rules" card ("Chores & rotations" opens the chore form with repeating on; "Run due chores now"). One form (`TemplateFormScreen`, `RecurrenceSections`) creates or edits a template and says whether it repeats, how often and who does it, replacing the separate New recurring screen; an existing recurrence is loaded and can be changed but not turned off (the API has no delete). Icon picker: a sheet of about 120 household emoji in six categories plus "No icon" (curated, no new dependency; a full Unicode picker would need `emoji_picker_flutter`, to be decided). Header, member row and stepper alignment fixed. On the household screen a template that repeats shows a green pill on the right of its card with how often ("Weekly", "Every 2 months"); at large text it goes under the points. The leaderboard has the household name above its title like the other tabs; the lists rename and archive actions are two round icon buttons instead of a three-dot menu (`RoundIconButton`). Left for the next slices: create-household and profile-sync screens (no board in the canvas beyond the Join or start a household one).

### T-0081 · Producers for the remaining notification types

* Status: done
* Issue / PR: — (suggested: "Send reassigned, overdue, dismissed and reverted notifications") / #75
* Depends on: T-0026
* Spec: §5
* Acceptance criteria: tasks-service queues `task_reassigned` (admin reassigns), `overdue` (a task passes its due date), `dismissed` (an admin dismisses someone else's task) and `reverted` (only when the task reopens with a future date, spec §3.3) in the transaction of the change; each has a relay test and appears in the recipient's inbox. Needed by the M6 exit (every spec §5 type).
* Summary: `OutboxService.enqueueForTask` queues a task event (taskId, taskTitle); the existing producers use it too. New producers in `TaskService`, all in the transaction of the change: `task_assigned` when an admin creates a task for someone else, `task_reassigned` to the new assignee, `dismissed` to the assignee when someone else dismissed it, `reverted` only when the revert reopens the task. An action on yourself notifies nobody. `overdue`: migration V7 (`task.overdue_notified_at`, partial index) and `ReminderService.sendOverdueNotices`, run every 60 s, which claims open tasks past their due date with `FOR UPDATE SKIP LOCKED` and notifies each once.
* Decisions and deviations: ADR 0017 addendum lists who is notified for what; every spec §5 type now has a producer. The `reason` of a reversion is not sent (not needed by the message, and it can be long). Dismissals caused by an away member or by `nobody_available` notify nobody (`marked_away` covers the first). A task dismissed because the revert came too late notifies nobody (spec). Found, not fixed: the older due-reminder job reads its candidates without a lock, so two replicas can queue the same reminder twice under different outbox ids (T-0085).
* Verification: JDK 21, Podman. `make test-backend SERVICE=tasks-service` (89 tests; 16 new: each producer and its negative cases, a revert that fails at the ledger leaves no event, overdue only once and not for done, dismissed or undated tasks, the limit, and four concurrent runs queue 20 notices once each) passes with Spotless, Checkstyle and the floors. Live on `make up` + `make seed`: bob's inbox received `task_assigned`, `dismissed`, `reverted` and, after its due time, `overdue`. `task_reassigned` was covered by tests only (with two members round robin picks the acting admin, who is not notified). Not run: the full `make test-backend` and e2e outside CI, Android.
* Follow-ups: T-0085 (duplicate due reminders), T-0082 (away text).

### T-0082 · The away notification text promises something that no longer happens

* Status: done
* Issue / PR: — (suggested: "Fix marked_away text: chores are dismissed, not passed on") / #76
* Depends on: T-0026
* Spec: §3.3 Away, §5
* Acceptance criteria: The `marked_away` title and body in `notifications_en/fr.properties` say what happens since T-0003 (open chores are dismissed, not passed on); the rendering test still covers both languages.
* Summary: The body now reads "Your open chores were dismissed." / "Vos tâches ouvertes ont été fermées." (it said "passed on" / "transmises"). `MessageRendererTest` gets a test that fails on the old text: the English body says "dismissed" and not "passed on", the French one says "fermées" and not "transmises".
* Decisions and deviations: Wording only; the titles are unchanged. "fermées" was chosen for the French because the spec's own term "dismissed" has no established app wording in French yet (the UI shows the English status names, T-0058).
* Verification: `MessageRendererTest` failed before the change and passes after; `make test-backend SERVICE=notifications-service` and CI. Not run: app, e2e outside CI.
* Follow-ups: none.

### T-0083 · Drop the unused title and body columns of tasks' outbox

* Status: todo
* Issue / PR: — (suggested: "Contract step for the tasks outbox")
* Depends on: T-0026
* Spec: AGENTS §4 (expand then contract)
* Acceptance criteria: A new Flyway migration drops `notification_outbox.title` and `.body` once no running replica writes them (T-0026 stopped writing them).

### T-0084 · Retry the tool downloads in CI and local setup

* Status: done
* Issue / PR: — (suggested: "A single 404 from Maven Central failed CI") / #74
* Depends on: T-0020, T-0073
* Spec: AGENTS §6.2
* Acceptance criteria: The downloads of the Dart client generator, Chrome for Testing, Flutter and the Android command-line tools retry on transient errors, so one failed fetch does not fail the build.
* Summary: Observed on PR #73: the `app` job failed in `make client` because the pinned generator jar answered 404 once from Maven Central (the same URL answered 200 a minute later, and in every earlier run); re-running the job passed. The four `curl` downloads in `tooling/` now use `--retry 5 --retry-all-errors --retry-delay 3`. Checksums are still verified after the download, so a retry never weakens the pin.
* Decisions and deviations: `--retry-all-errors` needs curl 7.71 or newer (the CI runners and Fedora have it). The localhost API calls in `deploy/` are left alone.
* Verification: syntax check of the three scripts; `make client` (jar cached, so no download), `make test-guard` and the PR's CI run. Not reproduced: the 404 itself.
* Follow-ups: none.

### T-0085 · Due reminders can be queued twice when several replicas run

* Status: done
* Issue / PR: — (suggested: "Reminder job has no row claim") / #77
* Depends on: T-0081
* Spec: §5, AGENTS §3 Scheduling
* Acceptance criteria: `ReminderService.sendDueReminders` claims its candidate tasks with `FOR UPDATE SKIP LOCKED` (as `sendOverdueNotices` does), so two replicas never queue the same reminder under different outbox ids; a test runs several concurrent calls and finds one reminder per task.
* Summary: The candidate query is now a native `SELECT id ... FOR UPDATE SKIP LOCKED` followed by loading each task, like the recurrence spawn and the overdue job. `NotificationProducersTest.severalReplicasNeverQueueTheSameReminderTwice` runs four concurrent calls over 20 due tasks: before the fix it found 80 reminders (4 per task) on each of three runs; now 20.
* Decisions and deviations: No row limit, as before: whether a reminder is due depends on household settings computed in code, so a SQL limit could starve rows. The locks are held during the per-household settings lookups, as the transaction already did.
* Verification: the new test failed before (80 instead of 20, three runs) and passes after; `make test-backend SERVICE=tasks-service` and CI. Not run: e2e outside CI.
* Follow-ups: none.

### T-0086 · App: push permission prompt and device token registration

* Status: todo
* Issue / PR: — (suggested: "Register the device for push")
* Depends on: T-0027, T-0028
* Spec: §5
* Acceptance criteria: Split from T-0028 on 2026-10-14. The app asks for push permission at a sensible moment (not at first launch), obtains the FCM or APNs token and registers it through the device-token API of T-0027, and removes it on sign-out. FR/EN, widget tests with a fake of the vendor boundary, e2e against the fake push endpoint (T-0077). Android only until iOS signing exists.

### T-0087 · The ledger sum can go below zero after an adjustment followed by a reversal

* Status: todo
* Issue / PR: — (suggested: "Reverse can push a member's ledger below zero") — needs a product decision first
* Depends on: T-0030
* Spec: §3.4 ("scores never go negative: reversals equal what was awarded, and manual adjustments are guarded"), AGENTS §7
* Acceptance criteria: Found by the T-0030 ledger tests, documented in `LedgerSequenceTest`. `reverse` checks that the task has enough points left, not the member's total, so a manual adjustment of -5 followed by reversing a 5-point task leaves the member's ledger sum at -5 while the score shown stays at 0; later awards then show as 0 until the sum is back above zero, hiding points the member earned. Decide: refuse the reversal, clamp it, or keep the behavior and say so in the spec; then change the code, the spec and the test together.

### T-0091 · App: restyle the quick-log picker after the design

* Status: in-review
* Issue / PR: — (suggested: "Quick-log picker after the design's Quick log board")
* Depends on: T-0090
* Spec: §8.2
* Acceptance criteria: The template picker opened by "+ I just did…" follows the design canvas' Quick log board (shared widgets and tokens, ADR 0021) instead of a stock `SimpleDialog`, with the same behavior (one tap on a template starts the 5-second cancel window). Update the widget tests, goldens and the e2e journeys that tap the dialog options.
* Decisions and deviations: delivered in the T-0080 pull request (sixth slice), see its entry. The stock `SimpleDialog` remains for the two "make recurring" pickers (New recurring board, still to do).

### T-0092 · Self-hosted fallback runner for CI

* Status: in-review
* Issue / PR: — (suggested: "CI minutes quota") / this PR
* Depends on: T-0070
* Spec: AGENTS §6.2, ADR 0024
* Summary: Installed a GitHub runner (label `fallback`) on the dev machine as a user systemd service with the Podman socket as Docker API. `check.yml` takes its runner from the repository variable `CI_RUNNER`, defaulting to `ubuntu-24.04`.
* Decisions and deviations: Manual switch instead of an automatic fallback (ADR 0024). The workflow-level `DOCKER_HOST` was removed; the runner service provides it. `CI_RUNNER=fallback` is set from the start of this PR, so CI runs on the fallback runner; `gh variable unset CI_RUNNER` returns to hosted. One runner is enabled (label `fallback` plus `fallback-e2e`, which the `e2e` job requires because its stack uses fixed ports), so the jobs run one after another. Two more are installed but disabled: parallel jobs collided on port 8081 (fixed by T-0093), then made `e2e` and the Testcontainers start-up unreliable on this machine (ADR 0024). The `e2e` job now runs `make down` in an `always()` step: `make e2e` leaves the stack up and the second run on the same host failed on taken ports.
* Verification: PR #90 checks (docs, app with goldens, five backend jobs, e2e, check) all passed on the fallback runner, with one runner, about 15 minutes in sequence. A run with three runners failed on the port collision above. Not run: `make check` locally as a whole.
* Follow-ups: T-0097 (flaky first e2e journey).

### T-0096 · `deploy/migrate.sh` waits for Postgres

* Status: in-review
* Issue / PR: — (suggested: "e2e fails with 'Connection to postgres:5432 refused' in migrate") / this PR
* Depends on: —
* Spec: AGENTS §3 (migrations as a one-shot job)
* Summary: `compose up -d postgres keycloak` returns before Postgres accepts connections and Flyway does not retry by default, so the migration step raced Postgres startup. It failed the `e2e` job on master (run 38911989381) and on #91 (run 38912473405) on the self-hosted runner, where warm images make the race easy to lose; hosted runners mostly won it. `migrate.sh` now passes `-connectRetries=60` to Flyway.
* Decisions and deviations: Flyway's own retry (one try per second, up to a minute) rather than a separate wait loop: one flag, and the same behaviour an init container would want on OpenShift.
* Verification: a throwaway Postgres (own network, no published port) started right before `migrate.sh`: before the change it exits 1 with `Connection to postgres:5432 refused`; after it, two runs end with `All databases migrated.` Not run: `make e2e`, `make check`.
* Follow-ups: none.

### T-0093 · Backend tests bind a random port so jobs can share a host

* Status: in-review
* Issue / PR: — (suggested: "Backend tests collide on port 8081 on a shared CI host") / this PR
* Depends on: —
* Spec: AGENTS §5.1
* Summary: `quarkus.http.test-port=0` in the five services. Quarkus' default test port is 8081 for every service, so two backend jobs on one host (or a backend job beside the `e2e` stack, which publishes 8081-8085) failed with `Port already bound: 8081` (run 38908224906 on the self-hosted fallback runner). Hosted runners hid it because each job has its own VM.
* Decisions and deviations: Test configuration only; production ports are unchanged. No test hardcoded a service port.
* Verification: see the PR description.
* Follow-ups: once merged, enable the other fallback runners (`systemctl --user enable --now github-runner-2 github-runner-3`, ADR 0024) and check the `e2e` job beside backend jobs.

### T-0094 · App: manage chore templates from the household screen

* Status: in-review
* Issue / PR: — (suggested: "Add and edit templates in the app") / this PR
* Depends on: —
* Spec: §3.1, §8.2
* Summary: The household screen has a "Chore templates" section: cards with emoji, title and points, an "Add a template" button for admins, and an edit form opened by tapping a card (title, emoji, description, points, late points). `TasksRepository.updateTemplate` was added (HTTP through the generated client, and the fake); the backend already had `PATCH /templates/{id}`. Members see the list read-only. Failures show the generic snackbar.
* Decisions and deviations: Product decision from the owner: templates live in the household management screen, not in the quick-log picker. Covers the template part of T-0075; creating open tasks and accepting an invitation without a household are still open there. Archiving a template from the app was not asked for and is not included. The quick-log stub that creates a "Chore" template when none exists is left as is.
* Verification: `flutter analyze` clean, `flutter test` 394 passed (new: `household_templates_test.dart` for add, edit, clear emoji, cancel, validation, refused save, member view, French at 200% text, accessibility guidelines; fake and contract tests for `updateTemplate`; new golden `household_detail_templates` in EN and FR; two existing household goldens regenerated). Not run: `make check` as a whole, `make e2e`.
* Follow-ups: an `integration_test` step for adding and editing a template; archive action; member names instead of ids on the same screen (T-0058). `app/test/failures/*.png` are tracked in git, which looks accidental.

* Decisions and deviations: Manual switch instead of an automatic fallback (ADR 0024). The workflow-level `DOCKER_HOST` was removed; the runner service provides it. `CI_RUNNER=fallback` is set from the start of this PR, so CI runs on the fallback runner; `gh variable unset CI_RUNNER` returns to hosted. Three runners (labels `fallback`; the first also `fallback-e2e`, which the `e2e` job requires because its stack uses fixed ports) so the jobs run in parallel. The `e2e` job now runs `make down` in an `always()` step: `make e2e` leaves the stack up and the second run on the same host failed on taken ports.
* Verification: PR #90 checks (docs, app with goldens, five backend jobs, e2e, check) all passed on the fallback runner, with one runner, about 10 minutes in sequence; rerun with three runners to be confirmed in the PR. Not run: `make check` locally as a whole.
* Follow-ups: watch memory (15 GB) when `e2e` runs beside `app` and backend jobs.

### T-0095 · `make run-app`: try the app by hand against the local stack

* Status: in-review
* Issue / PR: — (suggested: "One command to run the app locally") / this PR
* Depends on: —
* Spec: AGENTS §6.1
* Summary: `make run-app` (`tooling/run-app.sh`) starts the stack (`make up` with the web port in CORS), creates the Keycloak users `alice` and `bob` (password `demo`, local only), and serves the release web build on http://localhost:8090 until Ctrl-C. `RUN_APP_SEED=1` also runs `make seed`; `RUN_APP_STACK=running` reuses a stack that is already up. README and the AGENTS §6.1 table document it.
* Decisions and deviations: Same dart-defines and web build as `tooling/e2e.sh`, but without chromedriver or journeys. Push notifications are not delivered locally (stated in the README), as the owner accepted.
* Verification: `make run-app` from a clean machine: stack up and smoke-checked, app compiled and served on :8090, real browser sign-in as `alice` through Keycloak (`test_driver/web_sign_in.dart`: OK). Against the running services, with alice's token: create a household, create a template, edit it (emoji cleared), quick-log it; the logged task carried the edited title and 7 points. Not run: the templates screen in a real browser by hand (covered by widget tests), `make check`.
* Follow-ups: none.

### T-0097 · e2e: the first journey fails intermittently when creating the household

* Status: todo
* Issue / PR: — (suggested: "e2e first journey flaky: household not found after creation")
* Depends on: T-0021
* Spec: AGENTS §6.2
* Acceptance criteria: `household_journey_test.dart` "sign in profile sync, create a household…" sometimes fails at `firstWhere` (line 192, `Bad state: No element`: the household created through the UI is not in `listHouseholds()` yet) or with `FocusManager used after being disposed`, and every later journey then fails because they depend on its `householdId`. Seen on the self-hosted runner in runs 38925223407, 38936281427 and 38946063647 (a re-run of the same commit passed), and once on master on 2026-10-14 on a hosted runner (run 38611183796, cause not examined). Measured on 2026-10-16 on a quiet machine with a fresh stack per run (`make down`/`make up`; reusing one stack makes the second run fail on the first run's leftover notification, which is not this flake): 1 failure in 5 runs, so it is not caused by CI load. The failing run reports the first test as failed by `A FocusManager was used after being disposed` thrown after the test had completed, `householdId` is then never assigned, and the later journeys fail in cascade; the log has no per-step progress. One suspect, not confirmed: `_createHousehold` ends by waiting for `find.textContaining(name)`, which already matches the text field holding the typed name, so it can continue before Save has finished (this fits the `firstWhere` variant, not the `FocusManager` one). Instrument the steps, find the real first error, and make the journey wait for the real condition.

### T-0098 · Service images on the Red Hat hardened OpenJDK image

* Status: in-review
* Issue / PR: — / (this PR)
* Depends on: T-0004
* Spec: —
* Summary: The five `Dockerfile.jvm` use `registry.access.redhat.com/hi/openjdk:21.0-runtime` (non-root 65532, no shell) and start the jar with `java -jar` ([ADR 0025](decisions/0025-red-hat-hardened-base-image.md)).
* Decisions and deviations: Unused generated Dockerfile variants left alone. The catalog image needs no registry login.
* Verification: see the pull request.
* Follow-ups: T-0099 (hardened PostgreSQL for the local stack, suggested issue: "Use hi/postgresql in the local Compose stack").

### T-0099 · Local stack Postgres on the Red Hat hardened image

* Status: todo
* Issue / PR: — (suggested: "Use hi/postgresql in the local Compose stack")
* Depends on: T-0098
* Spec: —
* Acceptance criteria: `deploy/podman-compose.yml` uses `registry.access.redhat.com/hi/postgresql` (17 is the lowest tag found) instead of `postgres:16-alpine`; init script, healthcheck (`pg_isready`) and volume path work; Testcontainers keeps its own image.

### T-0100 · Publish the service images to GHCR when a pull request is merged

* Status: in-review
* Issue / PR: — / (this PR; stacked on T-0098)
* Depends on: T-0098
* Spec: —
* Summary: `publish-images.yml` builds the jars and the five images on each push to `master` and pushes `ghcr.io/<owner>/betterhome-<service>:<sha>` and `:latest` with `GITHUB_TOKEN`. `tooling/build-images.sh` does the build and push; README section "Container images"; [ADR 0026](decisions/0026-publish-images-to-ghcr.md).
* Decisions and deviations: Podman instead of Docker Buildx/actions so the same script runs on hosted and self-hosted runners. No test re-run, no signing or scanning (follow-ups).
* Verification: `tooling/build-images.sh` built all five images locally from the real jars; the workflow parses as YAML (no `actionlint` installed). Not verified: the login and push to GHCR, which only run on `master` after the merge; the run on `master` after this PR is the check.
* Follow-ups: image signing and vulnerability scan before push; image pull secret and deployment (T-0004).

### T-0103 · App: contrast of the dialog buttons in lists and the text prompt

* Status: todo
* Issue / PR: — (suggested: "App: AlertDialog buttons below 4.5:1 contrast")
* Depends on: T-0059
* Spec: AGENTS §5.2
* Acceptance criteria: The archive-list confirmation (`lists_screen.dart`) and `promptForText` use the same dialog surface as the dialogs fixed in T-0059 (or the theme sets it for all dialogs, with the month-recap golden regenerated), and scenarios open them with the accessibility checks.
