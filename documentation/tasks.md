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

* T-0080 · Restyle the existing screens with the shared widgets (slices done, see its entry)
* T-0119 · e2e journeys that need the clock (3 of 4 done: the month-end recap journey is left)

## Roadmap

Milestones in delivery order (vertical slice first). A milestone is reached when its exit criterion holds and its tasks are `done`. Reached on 2026-10-14: M1, M2, M3 and M4 (see the notes on each).

* **M1 · Real sign-in works** — T-0013, T-0014, T-0036. Exit: A Keycloak user can call every service, and invitations work over HTTP. **Reached.**
* **M2 · Toolchain, local stack, gates, CI** — T-0015, T-0016, T-0017, T-0005, T-0018. Exit: `make up` runs all five services; `make check` enforces AGENTS §5.3 and runs in CI on every pull request. **Reached**, except what the product owner parked: the dependency audit (T-0038), and image builds in `make check` (T-0046).
* **M3 · Services wired for real** — T-0010, T-0019. Exit: No in-memory gateway or ledger client left in main code; one app contract describes every endpoint. **Reached.**
* **M4 · App vertical slice on the real stack** — T-0020, T-0006, T-0021, T-0022. Exit: The app signs in through Keycloak and runs households, chores and leaderboard against `make up`; `make e2e` runs in CI. **Reached** (web target; Android sign-in not run, T-0045).
* **M5 · Lists (spec Phase 5)** — T-0023 (done), T-0024 (done). Exit: The Groceries tab journey passes end to end. **Reached** (the tab is named "Lists" in the design; reached from the household screen until the bottom bar, T-0031).
* **M6 · Notifications** — T-0025 (done), T-0026 (done), T-0027, T-0028, T-0086, T-0012, T-0077. Exit: Every notification type in spec §5 reaches a fake push gateway in the user's language, honoring preferences.
* **M7 · Spec completeness and polish (spec Phase 6)** — T-0029, T-0030, T-0031, T-0088, T-0089, T-0090, T-0032, T-0033, T-0076, T-0078. Exit: Every rule in spec §2–§9 is implemented and covered by an end-to-end journey.
* **M8 · Deploy and launch** — T-0004, T-0034, T-0035, T-0107, T-0108, T-0109, T-0110, T-0111, T-0112, T-0113, T-0114, T-0115, T-0116, T-0117 (and T-0086 for the push registration). Exit: The stack runs on OpenShift with migrations as Jobs, and signed store builds are produced. Blocked until an OpenShift cluster is available; until then Podman Compose is the target platform.

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

### T-0027 · Real push delivery through Gotify (was: FCM and APNs)

* Status: done
* Issue / PR: #20 / —
* Depends on: T-0025
* Spec: §5, AGENTS §8
* Acceptance criteria: Device-token registration API, FCM/APNs implementation of `PushSender` in notifications-service, minimal payloads (IDs and short text), invalid-token cleanup. Tests use an in-memory fake of the vendor boundary; e2e uses the fake push endpoint from T-0021. Changed by the issue owner's comment on #20, "Use Gotify for this": the vendor is Gotify, so "device token" becomes "the user's Gotify application token" and "vendor boundary" is the Gotify HTTP API.
* Summary: `GotifyPushSender` (JDK `HttpClient`, `POST {GOTIFY_URL}/message`, token in `X-Gotify-Key`, body = rendered title and message, priority 5, `extras["betterhome::push"]` with the type and the short-string payload) replaces `NoOpPushSender` in notifications-service when `GOTIFY_URL` is set (empty by default: nothing is pushed, the inbox is unaffected). Registration API `PUT/GET/DELETE /v1/push-target` (one Gotify application token per user, write-only), table `push_target` (migration V3). A 401, 403 or 404 from Gotify deletes the target (only if it still holds the refused token); other statuses, timeouts and connection errors are logged without token or text and the push is dropped. Contract regenerated (`make openapi`). Optional `gotify` Compose profile.
* Decisions and deviations: ADR 0027 (new) records the choice and the meaning of a "device registration" for Gotify; AGENTS §1/§3, spec §5/§6 figure and table, ADR 0013 and the README were amended from FCM/APNs to Gotify. Gotify cannot address a device: a message goes to the owner of the application token, so the target is the user's own application token and there is no global token. Token sent as a header, not `?token=`, to keep it out of URLs. Cleanup on 401/403/404 only, not on every 4xx: a 400 means our body was wrong, not that the user's token is. The token is stored in clear text (needed to replay it). Delivery stays at most once (ADR 0017). `GotifyPushSender` is an `@Alternative` at priority 1; the test `RecordingPushSender` moved to priority 2 so it still wins in tests. T-0086 and T-0077 reworded below.
* Verification: JDK 21, Podman. `./mvnw verify -pl services/notifications-service -am` passes (73 tests, Spotless, enforcer, JaCoCo floor, OpenAPI drift test), `make test-docs` passes; new tests `GotifyPushSenderTest` (request shape and token header, payload minimality, no target, no URL, 401/403/404 cleanup, other statuses and unreachable server keep the target, logs hold no token or text) against `FakeGotifyServer` (JDK `HttpServer`), and `PushTargetApiTest` (register, replace, read, remove, validation, per-user isolation, no profile 403, service account 403, anonymous 401, DB CHECK). Not run: a real Gotify server (the Compose profile was only validated with `podman compose config`), `make check`, `make e2e`.
* Follow-ups: T-0105 (delivery state and retries for push, so a Gotify outage does not drop pushes), T-0086 and T-0077 adapted to Gotify.

### T-0105 · Push delivery state and retries

* Status: todo
* Issue / PR: — (suggested: "Retry pushes that Gotify could not take")
* Depends on: T-0027
* Spec: §5
* Acceptance criteria: ADR 0017 left push at most once "until delivery state and retries". A push that failed with a timeout, connection error or 5xx from Gotify is recorded and retried with backoff (like the relays), a refused token is never retried, and a duplicate event never pushes twice. Tests with `FakeGotifyServer` and a fixed clock.

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

* Status: done
* Issue / PR: #25
* Depends on: T-0016, T-0025
* Spec: §9 Privacy, AGENTS §8
* Acceptance criteria: Deleting an account removes or anonymizes the user in Keycloak through the Admin REST API and anonymizes their data in every service while keeping the ledger consistent. Last-admin rule enforced. Tests in each service plus an e2e journey.
* Summary: `DELETE /v1/me` in households-service answers 202. In one transaction: last-admin rule (sole admin of a household with other members gets 409 until handing over), the user leaves every household, a household where they are the only member is deleted with them, queued outbox events and invitations to their address are dropped or blanked, the profile is anonymized and a surviving token cannot re-register (403 on sync). The remaining work (tasks, scoring, lists, notifications anonymize endpoints with the service token; Keycloak Admin `DELETE /users/{id}` behind `IdentityAdmin`) is recorded in `account_deletion`/`account_deletion_step` (migration V5) and retried by a 15 s scheduler with backoff until each target confirmed. Tasks, scoring and notifications gained the same anonymize endpoint as lists (T-0102). Orchestration is in ADR 0028; spec §9 states the last-admin and sole-member rules.
* Decisions and deviations: the anonymized profile row stays (needed to address the other services and for the retry record); retry has no limit, an error is logged after 10 attempts; Keycloak user is deleted, not disabled; the realm export gives the households service account `manage-users` of `realm-management`.
* Verification: `./mvnw verify` of households, tasks, scoring, lists and notifications; households tests cover service level, HTTP level, and a wiring test of the real REST clients against a fake HTTP server (service token, routes, 404/403/500/dropped connection); `make openapi`. Not verified: a real Keycloak (the `manage-users` grant and the Admin URL), the e2e journey (T-0106).
* Follow-ups: T-0106.

### T-0033 · Activity log

* Status: todo
* Issue / PR: #26
* Depends on: —
* Spec: §6.1, §6.2 ACTIVITY_LOG
* Acceptance criteria: Blocked: the spec lists ACTIVITY_LOG but does not say which service owns it, which actions are logged, or where users see it. Needs a product decision and a spec update before implementation.

### T-0034 · Observability: tracing and request IDs

* Status: done
* Issue / PR: #27
* Depends on: T-0016
* Spec: §7, AGENTS §8
* Acceptance criteria: OpenTelemetry tracing across services and outgoing REST calls, request IDs in MDC and JSON logs, no tokens, emails or message content in logs. Verified on the local stack.
* Summary: `quarkus-opentelemetry` in the five services (inbound REST and REST client calls are traced, `traceId`/`spanId` appear in the JSON log MDC). `common-domain` adds `RequestIdServerFilter` (accepts a well-formed `X-Request-ID` or generates a UUID, puts `requestId` in the MDC, echoes it in the answer) and `RequestIdClientFilter` (forwards it on every REST client call). `deploy/podman-compose.yml` gets an optional Jaeger under `--profile tracing`.
* Decisions and deviations: `quarkus.otel.traces.exporter` is build-time, so the off switch is the runtime sampler: default `parentbased_always_off` (trace ids exist, no span recorded or exported). Set `OTEL_TRACES_SAMPLER=parentbased_always_on` and `OTEL_EXPORTER_OTLP_ENDPOINT` to export (compose passes both). Caller ids that are not 8-64 chars of `[A-Za-z0-9_-]` are replaced. Existing code already logs no tokens, emails or message content; the test guards it. Background jobs (outbox relay, scheduler) have a trace id but no request id.
* Verification: `./mvnw verify` in `backend/` (all modules, JDK 21, Podman socket) passed. New tests: `RequestIdFiltersTest` (common-domain), `ObservabilityTest` (tasks-service: requestId and traceId in the JSON log file, request id and `traceparent` on the outgoing households call, caller `Authorization`/email absent from logs). On the Podman stack (`make up`, Jaeger via `--profile tracing`, `make seed`): `X-Request-ID` echoed, Jaeger shows tasks-service and households-service spans in the same trace, no token or email in the five containers' logs. Not run: `make check` (e2e, app launch).
* Follow-ups: other services have no tracing/log-leak test of their own (the filters and config are shared); a production OTLP collector belongs to the OpenShift deployment (T-0004).

### T-0035 · Release pipeline and store listings

* Status: todo
* Issue / PR: #28
* Depends on: T-0021, T-0004
* Spec: §1, §10 Phase 6
* Acceptance criteria: Signed Android and iOS builds from CI, store listings in FR and EN. Blocked on the pricing and monetization decision (spec §1).

## Discovered

### T-0120 · The Podman API exits when idle and breaks the Testcontainers start between test classes

* Status: done
* Issue / PR: — / (this PR)
* Depends on: T-0015
* Spec: AGENTS §6
* Acceptance criteria: `make test-backend SERVICE=households-service` passes on a machine set up by the repository's tooling; `make doctor` fails when the Podman API would exit while idle.
* Summary: `podman system service` exits after 5 idle seconds by default. In households-service several test classes restart Quarkus (`@QuarkusTestResource(restrictToAnnotatedClass)`), and shutting the previous application down takes about 5 seconds; the next Testcontainers Postgres start then failed with `java.io.IOException: Broken pipe` (`HttpNotificationsGatewayTest` errored and skipped the other 12 tests of its class). `tooling/configure-podman-api.sh` (idempotent; called by `tooling/install-dev-tools.sh`) writes a systemd user drop-in that runs the service with `--time=0` and restarts `podman.socket`; `make doctor` has a new check for it; README names the requirement.
* Decisions and deviations: Per-user systemd configuration under `~/.config`, no sudo. CI is not affected (hosted runners use Docker). The mechanism is inferred from the timing and confirmed by the result, not traced inside Testcontainers.
* Verification: before: `make test-backend SERVICE=households-service` failed the same way on an unchanged `master` (also earlier runs of tasks-service failed once on a cold start). After the drop-in: 101 tests, 0 failures, 0 skipped. The script run twice (second run changes nothing); `make doctor` reports MISSING with the drop-in removed and ok with it. Not run: a fresh machine through the whole installer.
* Follow-ups: none.

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

* Status: in-review (manifests written and rendered offline; never applied to a cluster, because none is available: product owner, 2026-10-13. Local runs stay on Podman Compose: ADR 0003, AGENTS §6.1)
* Issue / PR: #1
* Depends on: T-0001
* Spec: §7, ADR 0003
* Acceptance criteria: Deployments, Routes, ConfigMaps/Secrets, health probes, and migration Jobs for each service on OpenShift Local or a cluster.
* Summary: Kustomize base `deploy/openshift/base` with, per service, a Deployment (2 replicas, startup/liveness `/q/health/live`, readiness `/q/health/ready`, restricted-SCC security context), Service, edge-TLS Route and a Flyway migration Job, plus ConfigMaps (shared and per service; the Flyway SQL is generated from `backend/**/db/migration`). Overlay `deploy/openshift/crc` sets the namespace, one replica, the Keycloak issuer URL. Secrets are not committed: `crc/secrets.example.yaml` is a placeholder template outside the kustomization. Images are the GHCR ones of T-0100. Usage in `deploy/openshift/README.md`.
* Decisions and deviations: Health paths are `/q/health/*` (Quarkus default root), not `/health/*` as AGENTS §3 says in short. Migrations use the `flyway/flyway:11-alpine` image of the Compose stack with the SQL mounted from a ConfigMap, so the app images stay migration-free. The ConfigMap sources sit outside the kustomization root, so rendering needs `--load-restrictor=LoadRestrictionsNone`. PostgreSQL and Keycloak are prerequisites, not part of the overlay (T-0104). Every service gets a Route as the acceptance criteria say; internal endpoints stay protected by the `service` role. `make test-openshift-ports` (no tooling, in `make check`) checks ports, probe paths and images against `application.properties`; `make test-openshift` (kustomize/oc/kubectl, optional) renders and schema-checks, and is not in `make check` because CI has none of those tools.
* Verification: `kustomize build` v5.8.3 renders `deploy/openshift/crc` (31 resources) and `kubeconform` v0.8.0 `-strict` finds 26 valid, 0 invalid, 5 skipped (the Routes, no schema). `make test-openshift-ports` passes. NOT verified: any `oc apply`, pod start, probe success, Flyway under an arbitrary UID, Route reachability, Keycloak/Postgres wiring, `oc kustomize` itself.
* Follow-ups: T-0104.

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

* Status: done
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

* Status: dismissed (the product owner dropped the dependency audit; it needed an NVD API key)
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

* Status: done
* Issue / PR: #37 / (this PR)
* Depends on: T-0016, T-0018
* Spec: AGENTS §5.3
* Acceptance criteria: `make check` / CI builds the five images from the packaged jars and runs `make smoke`; the Dockerfiles' `EXPOSE 8080` matches the real service ports (8081-8085).
* Summary: New `make test-images` (in `make check`) runs `tooling/check-image-ports.sh` (every `Dockerfile.*` must EXPOSE the service's `quarkus.http.port`), packages the jars and builds the five images with `tooling/build-images.sh`. `Dockerfile.jvm` now has `EXPOSE 8081-8085`; the unused variants' `EXPOSE`/`docker run` lines use the real port too. CI has a new `images` job (required by the `check` job).
* Decisions and deviations: `make smoke` needs the whole stack (Postgres, Keycloak, migrations), so it is not run a second time in `images`: it already runs inside `make up`, which `make e2e` (the `e2e` job) calls.
* Verification: `make test-images` with the jars packaged under JDK 21 (five images built with Podman 5.8, port check passes); `make -n check`; YAML parse of `check.yml`. NOT verified: the new CI job on GitHub, `make check` in full, `make smoke`/e2e.
* Follow-ups: none.

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

* Status: done
* Issue / PR: #40 / not opened yet
* Depends on: T-0039
* Spec: AGENTS §5.1 (API contract)
* Acceptance criteria: Requests that tests send as valid are validated against the request schemas of the contract, while tests that send invalid requests on purpose are not rejected by the filter.
* Summary: `ContractValidation.validRequests(service)` (common-domain test-jar, next to the response filter) validates a request against the committed contract before it is sent and fails on an undocumented path or method, a wrong parameter, content type or body. It is opt-in: the happy-path helpers `createList`/`addItem` in lists `ListsApiTest` and `validAs` in households `InvitationHttpTest` add it; the response filter stays installed for every call and is unchanged.
* Decisions and deviations: opt-in rather than global because tests send invalid requests on purpose and the validator cannot tell them apart. Credentials (`validation.request.security`) are ignored, tests authenticate through `@TestSecurity` without a header. The same closed in-memory contract copy is used, so an unknown field in a valid request fails. Proofs in lists `ContractValidationTest` (missing required field and unknown path fail the filter). Only lists and households helpers adopt it; tasks, scoring and notifications helpers are not converted.
* Verification: `./mvnw verify -pl common-domain,services/lists-service,services/households-service -am` (Spotless, Checkstyle, tests on real PostgreSQL, JaCoCo) passed. Not run: other services, Flutter, `make check`, e2e.
* Follow-ups: adopt `validRequests` in the happy-path helpers of tasks, scoring, notifications (suggested issue).

### T-0042 · HTTP tests for endpoints without one

* Status: done
* Issue / PR: #41 / none yet
* Depends on: T-0039
* Spec: AGENTS §5.1 (API contract)
* Acceptance criteria: Every endpoint of every service has at least one REST-assured call (success and error) so its answers are checked against the contract.
* Summary: Audit of every resource: lists, notifications and scoring already had HTTP calls for all endpoints, success and error. The gaps were in households (`GET /v1/me`, `PATCH`/`DELETE /v1/households/{id}`, member role, away set/clear, leave errors, `/v1/me` validation) and tasks (`dismiss-away` and `reassign-away` errors and counts, state conflicts, 404s, 400s, 403s). Added `MembershipHttpTest` (households, real tokens, 12 tests) and 10 tests in `TasksHttpTest`. The contract filter checks every answer.
* Decisions and deviations: The tests found `POST .../tasks/manual` answering 400 with an error body the contract did not document; `TaskResource.quickLog` now documents it and the OpenAPI files are regenerated (`make openapi`). `TasksHttpTest` now deletes the household's tasks before each test, because its list assertions share the database. The issue mentions a membership "remove" endpoint: none exists (members leave through `members/me/leave`), so nothing to test.
* Verification: `./mvnw verify` for `households-service` and `tasks-service` (JDK 21, Testcontainers through `podman system service`). `make e2e` and the app launch were not run.
* Follow-ups: `GET /v1/households/{id}/tasks?status=nonsense` answers 404 with no body instead of a 400 with the error body (suggested issue: "Reject an unknown task status filter with 400"); the test for it was left out until it is fixed.

### T-0053 · Require the CI `check` job on master

* Status: dismissed (the product owner does not want branch protection; merging stays governed by AGENTS §6.2)
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

* Status: done
* Issue / PR: #44 / (pull request to follow)
* Depends on: T-0022
* Spec: AGENTS §5.2
* Acceptance criteria: Goldens show real text and icons by loading a bundled test font in `app/test/support/screen_harness.dart`; regenerated on Linux (ADR 0012).
* Summary: `pumpScreen(realFonts: true)` loads every font in the app's `FontManifest.json` (Figtree, Bricolage Grotesque, Material and Cupertino icons) with `FontLoader`; the three golden tests (`screens_baseline_test`, `widgets_test`, `design_system_test`) set it. All goldens regenerated on Linux.
* Decisions and deviations: No binary added and no Roboto: the theme uses Figtree and Bricolage Grotesque (OFL, licenses already in `app/assets/fonts`, T-0079) and Flutter bundles Material Icons through `uses-material-design`, so the goldens show the fonts the app really ships. Fonts cannot be unloaded and `textContrastGuideline` samples anti-aliased pixels, so it reports false failures (for example 1.06:1) on real glyphs; real fonts are therefore opt-in and each file declares its golden tests after its accessibility tests (a misordering fails loudly, never silently passes). Emoji in chore titles still render as empty boxes (no emoji font bundled).
* Verification: `make client`, `make update-goldens`, then `flutter test` (441 pass), `flutter analyze` and `dart format --set-exit-if-changed .` clean, on Linux. Not run: the rest of `make check`, e2e.
* Follow-ups: Optionally bundle an emoji font for the golden tests (large binary, product owner's call); a contrast check that does not depend on glyph pixels.

### T-0058 · Externalize remaining hard-coded strings and raw ids in app screens

* Status: done
* Issue / PR: #45 / (this PR; stacked on #107, T-0079 golden fonts)
* Depends on: T-0022
* Spec: AGENTS §9; §2 (members named on screen)
* Acceptance criteria: Chores status and points labels, the default template title and member labels (currently raw user ids) come from ARB keys or the members API in FR and EN; goldens regenerated.
* Summary: The chores meta line uses ARB keys (`taskStatusOpen/Done/Dismissed/Reverted`, `taskStatusWithPoints`, and the existing `pointsLabel`) instead of the enum name and a literal "pts". The members API had no names, so `MembershipResponse` now carries `givenName` and `familyName` (omitted once the account is deleted; OpenAPI documents regenerated with `make openapi`). Household detail, leaderboard (rows, podium, recap, hall of winners) and the fixed-assignee picker label members through `memberLabel`: "You" for the signed-in person, else the name, else the ARB key `unknownMember`. FR and EN ARB, generated l10n and the affected goldens updated.
* Decisions and deviations: The "Chore" template title named in the issue no longer exists in `app/lib` (the restyle removed it; the only "Chore" left is text a test types), so nothing to externalize there. Names are exposed to fellow household members only, never the email. `MembershipResponse.from` looks the user up per member (small households, no batch query).
* Verification: `make client`, `make openapi`, `./mvnw verify -pl services/households-service -am` (67 tests, Spotless, Checkstyle) with `givenName`/`familyName` asserted on the members list; from `app/`: `make update-goldens`, then `flutter test` (445 pass), `flutter analyze` and `dart format --set-exit-if-changed .` clean, on Linux; new `member_names_test.dart` (EN/FR names, fallback, no raw ids). Not run: the rest of `make check`, `make e2e` and the app against the real stack.
* Follow-ups: `app/test/failures/` holds committed golden failure images from #107 (should be gitignored; suggested issue).

### T-0059 · Golden and accessibility coverage for dialogs and non-admin views

* Status: done
* Issue / PR: #46 / (pull request to follow; stacked on #107, T-0057)
* Depends on: T-0022, T-0057
* Spec: AGENTS §5.2
* Acceptance criteria: Scenarios for the non-admin household detail and chores views and for every dialog and snackbar, with goldens and accessibility checks in FR and EN.
* Summary: `screens_baseline_test.dart` gains 13 scenarios (accessibility, 200% text scale and golden, FR and EN): household detail and chores as a plain member (a test double lists an admin plus the signed-in member, since `FakeHouseholdsRepository` only knows its own user), the invite, invite-created, accept-invitation, dismiss-confirmation and revert dialogs (opened through the UI, fields filled), and the toasts (spawned count, recurrence saved, quick-log with undo, error). A scenario can now run an `act` step after the screen is pumped. 32 new goldens, no existing golden changed.
* Decisions and deviations: Create-template and make-recurring are full screens, not dialogs, and already have the `template_form` and `recurring_form` scenarios, so none was added. The new checks found two real defects in production code, fixed minimally: `AlertDialog` buttons in household detail and chores had 4.26:1 contrast on the default tinted dialog surface (they now use `AppTokens.card`, as a white dialog gives enough contrast), and the revert dialog overflowed by 14 px at 200% text (its content now scrolls). A global `dialogTheme` would have been simpler but also changes the month-recap dialog, hence the `leaderboard_recap` goldens, so it was not used. Toast scenarios advance a fixed 500 ms so the countdown bar is deterministic.
* Verification: `make client`, `make update-goldens`, then `flutter test`, `flutter analyze` and `dart format --set-exit-if-changed .` in `app/` on Linux. Not run: the rest of `make check`, e2e.
* Follow-ups: see Discovered (dialog contrast in lists and the text prompt).

### T-0061 · Spec: who may reset a list, and archived-list rules

* Status: done
* Issue / PR: #50
* Depends on: T-0023
* Spec: §2, §4
* Acceptance criteria: Spec states who can bulk reset (T-0023 allows any active member), that items of an archived list are frozen (409), and that re-checking is a no-op; code follows if the decision differs.
* Summary: Product owner decided on issue #50: admins only. `ItemService.reset` requires the admin role (403 for a member). Spec §2 permissions and §4 now state the reset rule, the frozen archived lists (409) and the no-op re-check. `resetList` documents 403 "Not an active admin" in the OpenAPI contract.
* Decisions and deviations: The app (T-0024) still offers "Uncheck all" to every member, so a member now gets an error snackbar; hiding it for members is left to a follow-up.
* Verification: lists-service tests (service, HTTP and authorization matrix: resetList is admin-only), see the pull request for the `make` runs.
* Follow-ups: App: show "Uncheck all" to admins only (suggested issue, extends T-0024).

### T-0062 · tasks-service: body-less POST actions answer 415 without a Content-Type

* Status: done
* Issue / PR: #51 / —
* Depends on: —
* Spec: AGENTS §3 (API style)
* Acceptance criteria: `@Consumes` moves from class level to body-bearing methods in tasks-service (and any other service with the same pattern); a test posts an action without Content-Type and gets 2xx.
* Summary: `@Consumes(JSON)` now sits only on body-bearing methods in tasks (`TaskResource`, `TemplateResource`), households (`MembershipResource`; `InvitationAcceptResource` has none left) and scoring (`ScoreboardResource`). Tests post `complete`, `dismiss`, `reassign`, `dismiss-away`, `reassign-away`, `archive`, invitation accept, `leave` and `celebrate` with no Content-Type and expect 2xx (the tasks test failed with 415 before the change).
* Decisions and deviations: lists and notifications have no body-less POST; `RecurrenceResource`, `PreferenceResource` and the other resources only have body-bearing writes, so they keep the class-level annotation.
* Verification (local, GitHub Actions minutes exhausted; local PostgreSQL 16, no Docker): `make test-docs` OK; `spotless:check checkstyle:check` OK; `mvn verify` per service with coverage checks: households 57, scoring 86, lists 68, notifications 53 tests green; tasks 117 tests with 1 failure that also fails without this change (see Follow-ups). Not run: `make e2e`, `make test-app` (no Podman, Flutter or emulator here), so this is not `done`.
* Follow-ups: `RruleEnginePropertiesTest.aMonthlyRuleOnADayThatSomeMonthsLackSkipsThoseMonthsInsteadOfClamping` fails deterministically on the parent commit too (expected 29, was 30), so `make check` was red on tasks-service independently of T-0062. Fixed in T-0101.

### T-0063 · lists-service: anonymize user ids on account deletion

* Status: dismissed (duplicate of T-0102, merged in #111)
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

* Status: done
* Issue / PR: — / (this PR)
* Depends on: T-0019
* Spec: AGENTS §5.1 (API contract), ADR 0006
* Acceptance criteria: Response records of every service declare their always-present fields as required in the generated OpenAPI (for example `@Schema(required = true)` or `@NotNull`), so the generated Dart models are non-nullable and `need` in `app/lib/data/api_mappers.dart` can go. Contract and committed documents regenerated; the response validation (T-0039) keeps passing.
* Summary: Every response record of the five services marks its always-present fields `@Schema(required = true)`, including primitives (SmallRye does not mark `int` or `boolean` as required by itself); the nullable ones stay unmarked, decided from the database columns (`NOT NULL` or not) and the mapping code: for example `archivedAt`, `completedAt`, `dueAt`, `emoji`, `readAt`, the optional away and winner fields, and `IngestResponse.notification` (absent when an event is suppressed). The five `*-openapi.yaml` files and the aggregate are regenerated. In the app, the regenerated Dart models have non-nullable required fields, so `need` and the `?? default` fallbacks in `api_mappers.dart` are gone.
* Decisions and deviations: A response that lacks a required field now fails inside the generated model (an assertion in debug builds, a type error in release builds), so `call` in `api_support.dart` converts those two typed errors into `ApiException`, which keeps the behavior the user sees (an error, not a crash) and the existing test. Request records are unchanged. `ServiceInfo.authSubject` is required: it is the empty string, never null, when unknown. `ScoreboardResponse.yearMonth`, `from` and `to` stay optional: the first e2e run found them absent for the week and all-time views.
* Verification: `make openapi`; `make test-backend` per service on JDK 21 for scoring, lists, notifications and tasks (pass, with the contract and response validation tests); `make test-app`; `make e2e` (all journeys pass; a first run failed on the scoreboard fields above, which is how they were found). households-service: 88 tests pass, but `HttpNotificationsGatewayTest.aDroppedConnectionIsWorthRetrying` errors with a Testcontainers Postgres start failure (`Broken pipe`) and skips the other 12 tests of its class; it fails the same way on an unchanged `master` on this VM, so it is not caused by this change. Not run: CI.

### T-0072 · Decide where the web build keeps its tokens

* Status: in-review
* Issue / PR: — (suggested: "Web tokens are stored in localStorage")
* Decisions and deviations: Product decision from the owner: in memory only. On web `OidcAuthService` uses `OidcMemoryStore`, so a reload signs the user out; sign-in already opens in a new tab and answers over a `BroadcastChannel`, so no full-page redirect is involved. Android keeps `oidc_default_store`. ADR 0020 updated. The web sign-in journey checks that no token-like key is in `localStorage` or `sessionStorage`.
* Verification: `make e2e` (JDK 21, Podman) passes, including `web_sign_in.dart`. Not covered: that a reload signs out (the journey ends with sign-out), Android.
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

* Status: dismissed (product decision: templates are created from the household management screen, in a full-screen form, by admins only; that is already built, see the entry above)
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

* Status: done
* Issue / PR: — (suggested: "Controllable clock for e2e") / (pull request to follow)
* Depends on: T-0021
* Spec: AGENTS §6.2
* Acceptance criteria: A clock that can be moved, exposed only in the test environment of the services (never in production profiles), used by `make e2e` for the journeys that depend on time: recurrence spawn and round-robin assignment, supersede, away reassignment, month-end recap. Also the journeys left from T-0021: leaderboard period views, household switcher with two households, French and English.
* Summary: `SystemClock` (common-domain, used by all five services) can run ahead of the system time by an offset, and `TestClockResource` (`GET`/`PUT /v1/test/clock`, `{"offsetSeconds": n}`, any signed-in member) moves it. The endpoint answers 404 unless `BETTERHOME_TEST_CLOCK_ENABLED=true`: the local Compose file defaults it to `false`, only `tooling/e2e.sh` turns it on, `make test-nas` fails if `deploy/nas` or `deploy/openshift` mention it, and it is excluded from the OpenAPI documents and the generated client. New journey "time travel": alice makes a household and invites bob, a daily round-robin recurrence spawns its first task, the tasks clock is moved 36 hours ahead, and the second occurrence goes to the other member while the first is dismissed as superseded; the clock is put back in a `finally`.
* Decisions and deviations: scope split, as T-0021 did. Done here: the mechanism in every service and the journey for recurrence spawn, round-robin assignment and supersede. Moved to T-0119: the journeys for away reassignment, the month-end recap, leaderboard period views and French/English (the household switcher journey already exists). A runtime switch rather than a build-time one, so the images `make up` builds and the published ones are the same; the guard is the default `false`, the OpenAPI exclusion and the `make test-nas` check. Test dependency `quarkus-rest` in common-domain (managed by the Quarkus BOM) only gives the unit tests a JAX-RS runtime to build a `NotFoundException`. The journey moves only the tasks clock; the other services follow the real time.
* Verification: common-domain unit tests (`SystemClockTest`, `TestClockResourceTest`) run locally with Spotless and Checkstyle clean; `make test-nas`, `make test-docs`, `bash -n tooling/e2e.sh`. **Not run:** the Quarkus tests, `make e2e` and the app checks (no container runtime, Flutter or Chrome here): the pull request's CI is the first run, including the generated OpenAPI drift check that must not see the new endpoint.
* Closing note: done: merged in #145; CI green on the pull request and on `master` (run 237), the new journeys ran in CI e2e. The rest of the criteria is T-0119.
* Follow-ups: T-0119.

### T-0077 · Fake push gateway endpoint for e2e

* Status: done
* Issue / PR: — (suggested: "Fake push gateway for e2e")
* Depends on: T-0021, T-0027
* Spec: AGENTS §6.2, §3 Push
* Acceptance criteria: (Gotify since T-0027, ADR 0027: the fake is a Gotify-compatible `POST /message` endpoint, `GOTIFY_URL` points at it, and the journey registers a token through `PUT /v1/push-target`.) The local and e2e stack runs a fake push gateway endpoint that records what notifications-service sends; e2e journeys assert on it (type, language, minimal payload). Needed by the M6 exit.
* Summary: `make e2e` starts the stack with the optional `gotify` profile and `GOTIFY_URL=http://gotify:80`, waits for Gotify, creates an application through its API and passes its token to the journeys (`E2E_GOTIFY_APP_TOKEN`). The notifications journey registers that token as bob's push target (`PUT /v1/push-target`) before alice marks him away; after the journeys, `tooling/e2e.sh` reads the application's messages and requires a "Marked away" push whose `betterhome::push` extras hold the type `marked_away` and nothing else.
* Decisions and deviations: the recording endpoint is the real Gotify server of the local stack, not a hand-written fake: it already records every message and exposes them through its API, so there is no extra server to maintain and the request is checked against what Gotify really accepts. The check runs in the script, not in the Dart journey, because the web journey runs in a browser that cannot read another origin without CORS on Gotify. Only the English text is asserted: the journeys' users use the default language; a French assertion needs a user with that language setting and is left out. A stack started by hand (`E2E_STACK=running`) needs `COMPOSE_PROFILES=gotify GOTIFY_URL=http://gotify:80`; the script says so when Gotify is missing.
* Verification: `bash -n tooling/e2e.sh` and the jq filter tried on matching, extra-key and missing messages. **Not run:** `make e2e` and the Android target: this environment has no Podman, Flutter or Chrome, so the CI `e2e` job on the pull request is the first real run.
* Closing note: Done: merged in #143 with the CI `e2e` job green on the pull request and on `master` (run 233).
* Follow-ups: none new.

### T-0078 · `make check` runs the e2e suite

* Status: done
* Issue / PR: — (suggested: "Include e2e in make check")
* Depends on: T-0073
* Spec: AGENTS §6.1 (`make check` is everything above, as in CI)
* Acceptance criteria: `make check` runs `make e2e` like CI does (or AGENTS §6.1 states why not), without a second stack start when one is already up.
* Summary: `make check` now ends with `make e2e` (web target) after `test-app` and `test-guard`, so the local gate matches CI, where the `e2e` job runs the same script.
* Decisions and deviations: no second stack start: nothing earlier in `check` starts the stack (the backend tests use Testcontainers), and `e2e.sh` runs `make up`, which is idempotent, so a stack left up by `make up` is reused. `E2E_STACK=running` skips the start altogether. The CI `check` job still joins the parallel jobs and does not call `make check`, so CI timing is unchanged.
* Verification: `make -n check` shows the order; `make test-docs`. **Not run:** `make check` or `make e2e` here (no Podman, Flutter or Chrome): the CI `e2e` job runs the same script.
* Closing note: Done: merged in #144 (CI and `master` run 235 green); `make check` itself was not run here, it runs the same `make e2e` script the CI job runs.
* Follow-ups: none.

### T-0079 · Bundle the design fonts

* Status: done
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

* Status: done
* Issue / PR: — / (this PR)
* Depends on: T-0026
* Spec: AGENTS §4 (expand then contract)
* Acceptance criteria: A new Flyway migration drops `notification_outbox.title` and `.body` once no running replica writes them (T-0026 stopped writing them).
* Summary: tasks-service `V9__drop_outbox_title_body.sql` drops `notification_outbox.title` and `.body`. The entity and the relay no longer touch them (T-0026), so no code changed. `OutboxSchemaTest` asserts that the columns are gone and `payload_json` remains.
* Decisions and deviations: V6 was the expand step; this is the contract step. Deploy order: the migration runs as a separate job (AGENTS §3), so apply it after every replica runs the image from T-0026 or later; a replica older than T-0026 would still write the dropped columns and fail on insert.
* Verification: `make test-backend SERVICE=tasks-service` on JDK 21 (Spotless, Checkstyle, 147 tests, coverage floor) passes. Not run: other services, app, e2e, CI.

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

* Status: done
* Issue / PR: #125 / (pull request to follow)
* Depends on: T-0027, T-0028
* Spec: §5
* Acceptance criteria: Split from T-0028 on 2026-10-14. The app asks for push permission at a sensible moment (not at first launch), obtains the FCM or APNs token and registers it through the device-token API of T-0027, and removes it on sign-out. (Gotify since T-0027, ADR 0027: there is no OS token or permission prompt; the user pastes the application token of their Gotify app, the app registers it with `PUT /v1/push-target` and removes it with `DELETE` on sign-out.) FR/EN, widget tests with a fake of the vendor boundary, e2e against the fake push endpoint (T-0077). Android only until iOS signing exists.
* Summary: the notification settings screen has a "Push notifications" card: it says whether a Gotify token is registered, takes the application token (trimmed, checked against the contract's `[A-Za-z0-9._~-]` pattern before sending) and registers it with `PUT /v1/push-target`, and offers "Stop push notifications" (`DELETE`) while one is registered. `NotificationsRepository` gained `hasPushTarget` (`GET`, 404 means none), `registerPushTarget` and `removePushTarget`; the fake keeps the token for tests. Signing out removes the target first, while the access token is still valid. FR and EN strings; goldens `notification_settings_populated` regenerated and `notification_settings_push_on` added.
* Decisions and deviations: no OS permission prompt exists with Gotify (ADR 0027), so there is no "sensible moment" prompt: the card lives in the settings the bell opens. If removing the target fails at sign-out (offline, server down), the app signs out anyway rather than trapping the user; the target stays until the next registration or account deletion. Account deletion skips the removal (the server drops the target with the account). No new ADR: ADR 0027 already decides this.
* Verification: `make test-app` (format, analyze, widget, repository-against-contract and golden tests). Not done: the e2e journey against the fake push endpoint, because it needs T-0077 (still todo); the app was not launched against a real Gotify server. The e2e part is now in the T-0077 change (see below); its first real run is the CI `e2e` job.
* Closing note: Done: the registration journey and the push arriving at Gotify ran green in CI (#143, `master` run 233); what the e2e does not cover is in the follow-ups.
* Follow-ups: the e2e covers registering the token through the repository and the push arriving at Gotify (checked by `tooling/e2e.sh`, T-0077). It does not drive the settings card in the browser, nor sign-out removing the target: both are covered by widget tests only. Not launched against a Gotify Android client (T-0114).

### T-0087 · The ledger sum can go below zero after an adjustment followed by a reversal

* Status: done
* Issue / PR: — (suggested: "Reverse can push a member's ledger below zero") / #157
* Decisions and deviations: Product decision from the owner: refuse. `reverse` now also checks the assignee's ledger sum, like `adjust`, and answers 409 "Scores never go negative".
* Depends on: T-0030
* Spec: §3.4 ("scores never go negative: reversals equal what was awarded, and manual adjustments are guarded"), AGENTS §7
* Acceptance criteria: Found by the T-0030 ledger tests, documented in `LedgerSequenceTest`. `reverse` checks that the task has enough points left, not the member's total, so a manual adjustment of -5 followed by reversing a 5-point task leaves the member's ledger sum at -5 while the score shown stays at 0; later awards then show as 0 until the sum is back above zero, hiding points the member earned. Decide: refuse the reversal, clamp it, or keep the behavior and say so in the spec; then change the code, the spec and the test together.

### T-0091 · App: restyle the quick-log picker after the design

* Status: done
* Issue / PR: — (suggested: "Quick-log picker after the design's Quick log board")
* Depends on: T-0090
* Spec: §8.2
* Acceptance criteria: The template picker opened by "+ I just did…" follows the design canvas' Quick log board (shared widgets and tokens, ADR 0021) instead of a stock `SimpleDialog`, with the same behavior (one tap on a template starts the 5-second cancel window). Update the widget tests, goldens and the e2e journeys that tap the dialog options.
* Decisions and deviations: delivered in the T-0080 pull request (sixth slice), see its entry. The stock `SimpleDialog` remains for the two "make recurring" pickers (New recurring board, still to do).

### T-0092 · Self-hosted fallback runner for CI

* Status: done
* Issue / PR: — (suggested: "CI minutes quota") / this PR
* Depends on: T-0070
* Spec: AGENTS §6.2, ADR 0024
* Summary: Installed a GitHub runner (label `fallback`) on the dev machine as a user systemd service with the Podman socket as Docker API. `check.yml` takes its runner from the repository variable `CI_RUNNER`, defaulting to `ubuntu-24.04`.
* Decisions and deviations: Manual switch instead of an automatic fallback (ADR 0024). The workflow-level `DOCKER_HOST` was removed; the runner service provides it. `CI_RUNNER=fallback` is set from the start of this PR, so CI runs on the fallback runner; `gh variable unset CI_RUNNER` returns to hosted. One runner is enabled (label `fallback` plus `fallback-e2e`, which the `e2e` job requires because its stack uses fixed ports), so the jobs run one after another. Two more are installed but disabled: parallel jobs collided on port 8081 (fixed by T-0093), then made `e2e` and the Testcontainers start-up unreliable on this machine (ADR 0024). The `e2e` job now runs `make down` in an `always()` step: `make e2e` leaves the stack up and the second run on the same host failed on taken ports.
* Verification: PR #90 checks (docs, app with goldens, five backend jobs, e2e, check) all passed on the fallback runner, with one runner, about 15 minutes in sequence. A run with three runners failed on the port collision above. Not run: `make check` locally as a whole.
* Follow-ups: T-0097 (flaky first e2e journey).

### T-0096 · `deploy/migrate.sh` waits for Postgres

* Status: done
* Issue / PR: — (suggested: "e2e fails with 'Connection to postgres:5432 refused' in migrate") / this PR
* Depends on: —
* Spec: AGENTS §3 (migrations as a one-shot job)
* Summary: `compose up -d postgres keycloak` returns before Postgres accepts connections and Flyway does not retry by default, so the migration step raced Postgres startup. It failed the `e2e` job on master (run 38911989381) and on #91 (run 38912473405) on the self-hosted runner, where warm images make the race easy to lose; hosted runners mostly won it. `migrate.sh` now passes `-connectRetries=60` to Flyway.
* Decisions and deviations: Flyway's own retry (one try per second, up to a minute) rather than a separate wait loop: one flag, and the same behaviour an init container would want on OpenShift.
* Verification: a throwaway Postgres (own network, no published port) started right before `migrate.sh`: before the change it exits 1 with `Connection to postgres:5432 refused`; after it, two runs end with `All databases migrated.` Not run: `make e2e`, `make check`.
* Follow-ups: none.

### T-0093 · Backend tests bind a random port so jobs can share a host

* Status: done
* Issue / PR: — (suggested: "Backend tests collide on port 8081 on a shared CI host") / this PR
* Depends on: —
* Spec: AGENTS §5.1
* Summary: `quarkus.http.test-port=0` in the five services. Quarkus' default test port is 8081 for every service, so two backend jobs on one host (or a backend job beside the `e2e` stack, which publishes 8081-8085) failed with `Port already bound: 8081` (run 38908224906 on the self-hosted fallback runner). Hosted runners hid it because each job has its own VM.
* Decisions and deviations: Test configuration only; production ports are unchanged. No test hardcoded a service port.
* Verification: see the PR description.
* Follow-ups: once merged, enable the other fallback runners (`systemctl --user enable --now github-runner-2 github-runner-3`, ADR 0024) and check the `e2e` job beside backend jobs.

### T-0094 · App: manage chore templates from the household screen

* Status: done
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

* Status: done
* Issue / PR: — (suggested: "One command to run the app locally") / this PR
* Depends on: —
* Spec: AGENTS §6.1
* Summary: `make run-app` (`tooling/run-app.sh`) starts the stack (`make up` with the web port in CORS), creates the Keycloak users `alice` and `bob` (password `demo`, local only), and serves the release web build on http://localhost:8090 until Ctrl-C. `RUN_APP_SEED=1` also runs `make seed`; `RUN_APP_STACK=running` reuses a stack that is already up. README and the AGENTS §6.1 table document it.
* Decisions and deviations: Same dart-defines and web build as `tooling/e2e.sh`, but without chromedriver or journeys. Push notifications are not delivered locally (stated in the README), as the owner accepted.
* Verification: `make run-app` from a clean machine: stack up and smoke-checked, app compiled and served on :8090, real browser sign-in as `alice` through Keycloak (`test_driver/web_sign_in.dart`: OK). Against the running services, with alice's token: create a household, create a template, edit it (emoji cleared), quick-log it; the logged task carried the edited title and 7 points. Not run: the templates screen in a real browser by hand (covered by widget tests), `make check`.
* Follow-ups: none.

### T-0097 · e2e: the first journey fails intermittently when creating the household

* Status: in-review
* Issue / PR: — (suggested: "e2e first journey flaky: household not found after creation")
* Depends on: T-0021
* Spec: AGENTS §6.2
* Acceptance criteria: `household_journey_test.dart` "sign in profile sync, create a household…" sometimes fails at `firstWhere` (line 192, `Bad state: No element`: the household created through the UI is not in `listHouseholds()` yet) or with `FocusManager used after being disposed`, and every later journey then fails because they depend on its `householdId`. Seen on the self-hosted runner in runs 38925223407, 38936281427 and 38946063647 (a re-run of the same commit passed), and once on master on 2026-10-14 on a hosted runner (run 38611183796, cause not examined). Measured on 2026-10-16 on a quiet machine with a fresh stack per run (`make down`/`make up`; reusing one stack makes the second run fail on the first run's leftover notification, which is not this flake): 1 failure in 5 runs, so it is not caused by CI load. The failing run reports the first test as failed by `A FocusManager was used after being disposed` thrown after the test had completed, `householdId` is then never assigned, and the later journeys fail in cascade; the log has no per-step progress. One suspect, not confirmed: `_createHousehold` ends by waiting for `find.textContaining(name)`, which already matches the text field holding the typed name, so it can continue before Save has finished (this fits the `firstWhere` variant, not the `FocusManager` one). Instrument the steps, find the real first error, and make the journey wait for the real condition.
* Summary: The suspect in the entry was the cause of the `firstWhere` variant. `_createHousehold` ended with `find.textContaining(name)`, which the text field holding the typed name already matches, so the journey went on before Save was answered and `listHouseholds()` could still be empty. It now first waits until the household-name field is gone (the form closes only after the server answered), then looks for the name. The `FocusManager` variant is the same failure seen later: the test throws at `firstWhere`, the widget tree is disposed, and the framework reports the focus error after the test has ended. Every journey calls `_createHousehold`, so all of them wait on the real condition.
* Decisions and deviations: Only the wait changed; no timeout was raised and nothing was retried. I did not add per-step progress logging, because the failing step is now named by the `expect` in `_seeCount`.
* Verification: `make e2e` five times, each on a fresh stack (`make down` first): 5 of 5 passed. The failure rate before was about 1 in 5, so five passes is moderate evidence only (a 20% flake would still pass five times in a row about one run in three): watch the next CI runs, and reopen if it fails again. Not run: CI.

### T-0098 · Service images on the Red Hat hardened OpenJDK image

* Status: done
* Issue / PR: — / (this PR)
* Depends on: T-0004
* Spec: —
* Summary: The five `Dockerfile.jvm` use `registry.access.redhat.com/hi/openjdk:21.0-runtime` (non-root 65532, no shell) and start the jar with `java -jar` ([ADR 0025](decisions/0025-red-hat-hardened-base-image.md)).
* Decisions and deviations: Unused generated Dockerfile variants left alone. The catalog image needs no registry login.
* Verification: see the pull request.
* Follow-ups: T-0099 (hardened PostgreSQL for the local stack, suggested issue: "Use hi/postgresql in the local Compose stack").

### T-0099 · Local stack Postgres on the Red Hat hardened image

* Status: done
* Issue / PR: — / (this PR)
* Depends on: T-0098
* Spec: —
* Acceptance criteria: `deploy/podman-compose.yml` uses `registry.access.redhat.com/hi/postgresql` (17 is the lowest tag found) instead of `postgres:16-alpine`; init script, healthcheck (`pg_isready`) and volume path work; Testcontainers keeps its own image.
* Summary: `deploy/podman-compose.yml` runs `registry.access.redhat.com/hi/postgresql:17`. The image keeps the entrypoint conventions of the official one (`POSTGRES_*` variables, `/docker-entrypoint-initdb.d`, `PGDATA=/var/lib/postgresql/data`), so the init script, the `pg_isready` healthcheck and the volume path are unchanged. Testcontainers and the NAS stack keep `postgres:16-alpine`.
* Decisions and deviations: Local Postgres moves from 16 to 17; a `postgres-data` volume made by 16 cannot be opened by 17, so run `make down` (it removes volumes) once. The NAS stack is left on 16 on purpose: it holds real data and a major upgrade needs a dump and restore, not an image swap.
* Verification: `make down`, `make up` (smoke OK, container healthy), `make seed`, a Postgres restart that kept the seeded household, and `make e2e` (all journeys passed). Not run: CI.

### T-0100 · Publish the service images to GHCR when a pull request is merged

* Status: done
* Issue / PR: — / (this PR; stacked on T-0098)
* Depends on: T-0098
* Spec: —
* Summary: `publish-images.yml` builds the jars and the five images on each push to `master` and pushes `ghcr.io/<owner>/betterhome-<service>:<sha>` and `:latest` with `GITHUB_TOKEN`. `tooling/build-images.sh` does the build and push; README section "Container images"; [ADR 0026](decisions/0026-publish-images-to-ghcr.md).
* Decisions and deviations: Podman instead of Docker Buildx/actions so the same script runs on hosted and self-hosted runners. No test re-run, no signing or scanning (follow-ups).
* Verification: `tooling/build-images.sh` built all five images locally from the real jars; the workflow parses as YAML (no `actionlint` installed). Not verified: the login and push to GHCR, which only run on `master` after the merge; the run on `master` after this PR is the check.
* Follow-ups: image signing and vulnerability scan before push; image pull secret and deployment (T-0004).

### T-0103 · App: contrast of the dialog buttons in lists and the text prompt

* Status: done
* Issue / PR: — / (this PR)
* Depends on: T-0059
* Spec: AGENTS §5.2
* Acceptance criteria: The archive-list confirmation (`lists_screen.dart`) and `promptForText` use the same dialog surface as the dialogs fixed in T-0059 (or the theme sets it for all dialogs, with the month-recap golden regenerated), and scenarios open them with the accessibility checks.
* Summary: The archive-list confirmation and `promptForText` set `backgroundColor: AppTokens.card`, as the dialogs of T-0059 do. `screens_baseline_test.dart` gains `lists_new_list_dialog`, `lists_rename_dialog` and `lists_archive_dialog` (accessibility, 200% text scale and golden, FR and EN): 6 new goldens, no existing golden changed.
* Decisions and deviations: Same choice as T-0059: no global `dialogTheme`, because it would change the month-recap dialog and its goldens.
* Verification: with the two production changes stashed, 6 of the new accessibility checks fail; with them, `make update-goldens` then `flutter test`, `flutter analyze` and `dart format` in `app/` pass. Not run: e2e, CI.

### T-0101 · Recurrence: an occurrence in a daylight-saving gap at the end of the day moved to the next day

* Status: done
* Issue / PR: — / —
* Depends on: T-0011
* Spec: §3.1 (recurrence)
* Summary: `RruleEnginePropertiesTest` failed deterministically (seed `-4427577617696266686`: daily/monthly at 23:00 in `America/Godthab`, 2025-03-29, where local 23:00 does not exist). `RruleEngine` resolved the time with `atZone`, which shifts it forward by the gap, onto the 30th, so a rule on the 29th fired on the 30th and a daily rule fired twice on one calendar day. `occurrenceOn` now keeps the occurrence on its own day, at the day's last second, when the shift would cross midnight; other gaps keep the old forward shift. Spec §3.1 gets one sentence.
* Decisions and deviations: last second of the day chosen (not skipping the day, not the next day) so a rule never loses or duplicates an occurrence; the property oracle applies the same rule. No product behavior outside this edge changes.
* Verification: new `RruleEngineTest.anHourMissingAtTheEndOfTheDayKeepsTheOccurrenceOnItsOwnDay` failed before the fix; `mvn verify -pl services/tasks-service -am` green locally (118 tests, coverage checks met), `spotless:apply` clean. After merging master, the `check` job of the pull request passed on the fallback runner (docs, app, five backend jobs, e2e). Not run: Android target.
* Follow-ups: none.

### T-0102 · lists-service: anonymize a deleted user's id (part of T-0032)

* Status: done
* Issue / PR: #52 / —
* Depends on: T-0016
* Spec: §9 Privacy, AGENTS §8
* Summary: `POST /v1/internal/users/{userId}/anonymize` (role `service`, as the other internal endpoints, ADR 0014) replaces the user's id in `list.created_by`, `item.creator`, `item.completer` and `item.deleted_by` with the nil UUID and answers 200 with the rows changed per column. Repeating it, or naming a user with no history, answers 200 with zeroes. The nil UUID itself is refused with 400.
* Decisions and deviations: no migration. The columns are NOT NULL or tied to a timestamp by a CHECK and there are no foreign keys on them, so a sentinel id keeps the history ("someone checked it at 10:00") without making columns nullable. `updated_at` is left alone (anonymizing is not an edit). The sentinel is a constant in `AnonymizationService`; the app will see the nil UUID as the creator and should render it as "former member" (not done here, no app change). Spec §9 already says history is anonymized across services, so the spec is unchanged.
* Verification: `AnonymizeUserTest` (service and HTTP: success, only the named user's columns change, idempotent, unknown user, sentinel refused, household admin and role-less user 403, anonymous 401); `make openapi`; `./mvnw verify -pl services/lists-service -am`. Not verified: a call with a real Keycloak service token (the `betterhome-households-service` client already holds the `service` role, ADR 0014, but no real-token test hits this endpoint), e2e.
* Follow-ups: T-0032 still needs the households-side trigger and Keycloak Admin deletion, the call from households to this endpoint (it needs a REST client with the service token, failure policy so deletion is retried when lists is down), the same endpoint in tasks and scoring, the last-admin rule and the e2e journey. App: show the nil UUID as a former member.

### T-0104 · CRC: PostgreSQL and Keycloak for the OpenShift Local overlay

* Status: todo
* Issue / PR: — (suggested: "Run PostgreSQL and Keycloak on OpenShift Local")
* Depends on: T-0004
* Spec: §7
* Acceptance criteria: The CRC overlay (or a sibling) provides a `postgres` Service with the five databases and the Keycloak realm (Keycloak Operator, AGENTS §3), so `oc apply -k` gives a working stack. Needs a running cluster to verify.

### T-0106 · Account deletion: e2e journey and real Keycloak check (part of T-0032)

* Status: done
* Issue / PR: #25 / (pull request to follow)
* Depends on: T-0032
* Spec: §9 Privacy, AGENTS §8
* Acceptance criteria: An e2e journey deletes an account against the real stack (Keycloak included): last-admin refusal, hand-over, deletion, the Keycloak login gone, history shown under the nil UUID. Checks that the `manage-users` grant in `realm-betterhome.json` and `KEYCLOAK_ADMIN_URL` work against a real Keycloak. App: delete-account screen and rendering the nil UUID as a former member.
* Summary: the app has a delete-account screen (a person-with-minus action in the top bar of the signed-in app, explanation, confirmation dialog, the 409 last-admin refusal explained in FR and EN, any other failure as the generic error); a successful deletion ends the session (sign-out with an identity provider, back to the profile step in demo mode). `HouseholdsRepository.deleteMyAccount` (HTTP through the generated client, and the fake follows the same last-admin and sole-member rules). A new e2e journey with a throwaway user (carol, created by `tooling/e2e.sh`) is refused as the only admin, hands the role to bob through the API (the app has no hand-over screen), deletes the account from the screen, cannot sync with the old token (403), and shows bob the chore she did with her id replaced by the nil UUID; `e2e.sh` then waits until the user is gone from Keycloak.
* Decisions and deviations: no screen shows a former member's id today (the scoreboard lists active members only, chore cards show no assignee name), so there was nothing to render as "former member"; `memberLabel` already names any id it cannot find "Household member", and the journey checks the nil UUID through the tasks API instead. Demo mode (no identity provider) also offers the deletion so the e2e app can reach it; it returns to the profile step.
* Verification: `make e2e` on a fresh stack (`make down` first, web target): all journeys passed, the deletion journey against real Keycloak included, so the `manage-users` grant and the Admin URL work; `make test-app` (544 tests, 18 new baseline cases for the screen, dialog and refusal in FR and EN, plus delete_account_test and HTTP contract tests). Not run: the Android e2e target (T-0045), `make test-backend` (no backend change).
* Follow-ups: a hand-over screen for the admin role (the API exists, the app cannot call it), suggested title "Make another member an admin".

### T-0107 · ADR and design for the Caddy reverse proxy

* Status: done
* Issue / PR: #117 / (pull request to follow; stacked on #124)
* Depends on: —
* Spec: §7
* Acceptance criteria: ADR 0029 records the design: the NAS's existing Caddy and Tailscale (no Caddy or Tailscale of our own: a Caddyfile snippet to import plus a Compose file joining the shared `edge` network), one MagicDNS host that is only ever configured on the NAS (examples use `nas.example.ts.net`), path routing (`/auth` to Keycloak, `/api/<service>` to each service with the prefix stripped), TLS from tailscaled certificates (fallback `tls internal`, root CA installed on the phone), Keycloak behind a proxy, where Gotify is reached from the phone (decided there: a path under the same host or a second port; the Gotify app and its web UI must work), and why not subdomains (MagicDNS has none) or a public domain (exposes Keycloak and the APIs). Spec §7 gets one line. The app needs one base URL: it derives the Keycloak issuer (`/auth/realms/betterhome`) and the five service URLs from it (T-0115).
* Summary: ADR 0029 fixes the layout for T-0108 to T-0115: the NAS's existing Caddy stays the entry point (a Caddyfile snippet to import and a Compose file joining the shared `edge` network, no Caddy or Tailscale of our own), on the operator's tailnet host; `/auth` goes to Keycloak (relative path, prefix kept), `/api/<service>` to each service (prefix stripped, only `/v1/*` and `/q/health/*` forwarded), `/gotify` to Gotify; TLS from tailscaled certificates with `tls internal` as the fallback; Keycloak in production mode with the public URL as issuer and a dynamic back channel. Spec §7 has one paragraph and the ADR index a line.
* Decisions and deviations: Gotify is on a path (`/gotify`) rather than a second port, because Gotify supports a sub-path behind a proxy and one host keeps one certificate; T-0114 verifies the Android app and the web UI work that way. Consequence recorded: Tailscale certificates put the machine and tailnet name in public Certificate Transparency logs, so the name stays out of the repository but is not secret.
* Verification: `make test-docs`. Documentation only; nothing was run against Caddy or a NAS yet.
* Follow-ups: none new.

### T-0108 · NAS compose stack with Caddy

* Status: done
* Issue / PR: #118 / (pull request to follow; stacked on #130)
* Depends on: T-0107
* Spec: §7, AGENTS §3
* Acceptance criteria: `deploy/nas/compose.yml`, `deploy/nas/Caddyfile` and a README. The Caddyfile is a snippet for the NAS's existing Caddy (no host name in it, no catch-all) to `import` inside the tailnet host's site block. The Compose stack has no Caddy or Tailscale: the five services, Keycloak and Gotify also join the external `edge` network under `betterhome-*` aliases so Caddy reaches them, while Postgres and the Flyway one-shot jobs (as `deploy/migrate.sh`, never at startup; the services wait for them) stay on a private network. Values are inline with `CHANGE_ME` placeholders and there is no `.env` (NAS Docker UIs cannot be relied on to load one); real values exist only on the NAS. Images come from GHCR pinned by tag (ADR 0026); the packages are made public by the product owner, so no `docker login` is needed. Restart policies, healthchecks and a JVM heap cap for a NAS. The README says how to load the project in the UGOS Docker app or over SSH (written after trying it) and how to import the snippet, and a check shows its paths do not overlap with the routes of other apps on the host. `docker compose config` passes and a check proves no real hostname or secret is committed.
* Summary: `deploy/nas/compose.yml` (Postgres, an idempotent `init-databases` job, the `migrate` job, Keycloak, the five services and Gotify; only the containers Caddy must reach join the external `edge` network and their service names carry the `betterhome-` prefix, Postgres and the jobs stay private; inline `CHANGE_ME` values, no `.env`, no published port, memory limits per service), `deploy/nas/Caddyfile` (the snippet: `/auth`, `/api/<service>` with only `/v1` and `/q/health` forwarded and the rest 404, `/gotify`) and `deploy/nas/README.md` (install, check, first user, update, known limits). `tooling/check-nas.sh` (`make test-nas`, in `make check` and CI) checks the routes, ports, images, prefixes, private services, no published port, no `.env`, and that no real `.ts.net` name or password is committed.
* Decisions and deviations: the NAS has no checkout, so two more images are built and published (`betterhome-migrations`, `betterhome-keycloak`, ADR 0030); Keycloak's production mode is therefore delivered here, T-0109 keeps the secrets and the check on the real NAS. No health checks on the five services (their image has no shell or curl); Postgres and Keycloak have one. The service-client secret is still the development value of the baked realm (README says so, T-0109). Images use `:latest` in the file, pin a SHA to be safe.
* Verification: `make test-nas` (and four negative cases: a real `.ts.net` name, a published port, a plain password, a service without the prefix, each fails); all seven images built locally with `tooling/build-images.sh`; the stack from `deploy/nas/compose.yml` (images and placeholders swapped for local ones) started with `podman compose` behind a throwaway Caddy with `tls internal` that imported the snippet: the discovery issuer and the `iss` of a password-grant token were the public URL, all five `/q/health/ready` through `/api/<service>` returned 200, a user synced its profile, created a household, a template and read lists and the scoreboard (service-to-service calls worked), `/q/metrics` and `/q/openapi` answered 404, another path fell through to the other site, `/gotify/health` was green. Not verified: Docker Compose v2 (`podman-compose` ran it, but needed a second `up` for `service_completed_successfully`), the UGOS Docker app, a real Caddy and Tailscale certificate (T-0110), the images from GHCR (they only exist after the first merge), the Gotify Android app through the sub-path (T-0114).
* Follow-ups: how to load the project in the UGOS Docker app (to try on the NAS); T-0109 secrets.

### T-0109 · Keycloak production mode behind Caddy

* Status: done
* Issue / PR: #119 / (pull request to follow; stacked on #131)
* Depends on: T-0108
* Spec: §7, §9
* Acceptance criteria: Keycloak production mode itself (`start --optimized`, own database, `/auth` prefix, public hostname, proxy headers, dynamic back channel) is delivered by T-0108. This task replaces the development client secrets: the realm import takes the five service-client secrets from values set in the Compose file on the NAS (Keycloak `${ENV}` substitution; `CHANGE_ME` placeholders in the repository, development values kept for `make up`), the Compose services use the same values, and the admin console password is checked. Verified on the real NAS: a token fetched through the public URL is accepted by every service, and the development secret is refused.
* Summary: the six client secrets of `realm-betterhome.json` are now `${NAME:local-dev-only-change-me}` placeholders (`OIDC_SERVICE_CLIENT_SECRET` for the five service clients, the variable the services already read; `API_CLIENT_SECRET` for `betterhome-api`, the one `deploy/lib.sh` already uses). Keycloak substitutes them from its environment at import, so the baked image and `make up` keep the development value. `deploy/nas/compose.yml` gives Keycloak both values and the services the first, all `CHANGE_ME` placeholders edited on the NAS; `deploy/podman-compose.yml` passes the two variables to Keycloak too, so one override changes clients and services together. `make test-nas` now requires every password and secret in the Compose file to be a placeholder and the realm to hold no literal secret.
* Decisions and deviations: the five services keep sharing one secret (as before and as the services' configuration expects); one per service is a possible follow-up. The realm is imported once, on a first start: changing a secret later is done in the admin console and in the Compose file (README). The admin password was already a placeholder from T-0108. Not part of this task: the Keycloak production mode, delivered in T-0108.
* Verification: `make test-nas` (and negative cases for a literal secret in the Compose file, a missing variable, and the old development value). On a scratch Keycloak and then on the NAS stack run locally (local images, throwaway Caddy, distinct secrets): a service client gets a token with the new secret and 401 with the development one (all five, and `betterhome-api`); the admin login works with the configured password and not with a wrong one; a user token from `betterhome-api` is accepted by the services; tasks awarded points through scoring, scoring and tasks called households with their own tokens; an internal endpoint answers 403 to a user token and 200 to a service token. `SKIP_PACKAGE=1 make up` (smoke on :8081-:8085 passed) and `make seed` still work with the changed realm. Not verified: the real NAS (the first start there decides, check README), `make e2e` (the realm and the dev compose changed, the journeys use the defaults).
* Follow-ups: one client secret per service; rotation of the secrets without losing the realm.

### T-0110 · Tailscale and HTTPS certificates on the NAS

* Status: todo
* Issue / PR: #120 / —
* Depends on: T-0108
* Spec: §7
* Acceptance criteria: The BetterHome stack contains no Tailscale and no Caddy: the NAS's existing Compose stack already runs them. Documented and verified: how that Caddy imports `deploy/nas/Caddyfile` for the tailnet host, MagicDNS and HTTPS certificates enabled in the tailnet (with the Certificate Transparency consequence of ADR 0029), an ACL limiting access to the phone and the dev machine, and the phone on the tailnet with the Tailscale app. The tailnet name only ever exists on the NAS. Manual work on the NAS and in the Tailscale admin: needs the product owner.

### T-0111 · Android build against the NAS (`make apk`)

* Status: done
* Issue / PR: #121 / (pull request to follow; stacked on #132)
* Depends on: T-0107 (the phone check also needs T-0115 and a running NAS stack)
* Spec: §1
* Acceptance criteria: `make apk` builds a debug-signed APK for the dev phone, with no host baked in: the server URL is entered in the app (T-0115). Install steps (adb or a download over the tailnet). Verified on a real phone: after entering the server URL, sign-in through Keycloak works, the OIDC redirect returns to the app, a household can be created. The tailnet name is never written to a committed file or to an APK that is published. Release signing is T-0116.
* Summary: `make apk` (`tooling/build-apk.sh`) builds `app/build/app/outputs/flutter-apk/app-release.apk` in release mode, signed with the debug key as the release build type already is, and then checks the file: the `INTERNET` permission, the application id, the signer, and that no `.ts.net` name is inside a build made without `NAS_HOST`. README has install steps. A first version had `NAS_HOST=<host> make apk` for a personal build with the URLs baked in; T-0115 made it unnecessary and it was removed. **Bug fixed on the way:** the main `AndroidManifest.xml` had no `INTERNET` permission (only the debug and profile manifests did), so any release APK, this one and the F-Droid one, had no network.
* Decisions and deviations: release mode rather than `--debug` (60 MB, no debugger, the build users will get); the signing key stays the debug key until T-0116, so an APK built on another machine does not update this one (README). A fat APK (all ABIs) for simplicity. `make apk` depends on `make client` like `make e2e`.
* Verification: `make apk` built the APK (60.7 MB, `aapt`: `INTERNET`, `com.betterhome.betterhome`, signer `CN=Android Debug`, no server inside); the same build without the manifest fix fails the check with "the INTERNET permission is missing". Not verified: installing and running it on a phone (the Android emulator still crashes on the dev VM, T-0045), signing in through Keycloak and the redirect back to the app, creating a household (needs the NAS stack, Tailscale and a phone: T-0110 and the product owner).
* Follow-ups: T-0116 replaces the signing key.

### T-0112 · NAS smoke check (`make nas-smoke`)

* Status: done
* Issue / PR: #122 / (pull request to follow; stacked on #135)
* Depends on: T-0108, T-0109
* Spec: §7
* Acceptance criteria: From any tailnet machine: the certificate is valid, the discovery issuer under `/auth` equals the public URL, each service answers `/q/health/ready` through its prefix, Gotify answers its health endpoint, and one password-grant token is accepted by every service. Extends the pattern of `deploy/smoke.sh`.
* Summary: `deploy/nas-smoke.sh` (`make nas-smoke`) takes `NAS_URL`, `API_CLIENT_SECRET`, `SMOKE_USER` and `SMOKE_PASSWORD` from the environment (nothing is committed), and checks in order: TLS and Keycloak reachable (curl verifies the certificate), the issuer equals `$NAS_URL/auth/realms/betterhome`, `/api/<service>/q/health/ready` for the five services, `/gotify/health`, and a password-grant token accepted by `/api/<service>/v1/meta` of every service. It stops at the first failure with a message naming it. README "Check it" now points to it.
* Decisions and deviations: the user is not created by the script (unlike `smoke.sh`, which uses `kcadm` on a local container): on the NAS the realm has open registration or an admin-made user (README, First user), and the script runs from a different machine than the NAS. Not part of `make check` (needs the NAS).
* Verification: run against a fake HTTP server (Python, in the scratchpad, not committed) for the good case (exit 0, all steps), a wrong issuer, an unreachable host, and a wrong user (no token): exit 1 each with the expected message; missing variables fail with a message. Not run: a real NAS, a real certificate (T-0110, product owner).
* Follow-ups: none new.

### T-0113 · NAS operations: updates and backups

* Status: done
* Issue / PR: #123 / (pull request to follow; stacked on the T-0112 branch)
* Depends on: T-0108
* Spec: §7
* Acceptance criteria: `deploy/nas/update.sh` pulls a new SHA tag, runs the migrations and restarts the services. A nightly `pg_dump` of every database, plus the Gotify data volume, to a NAS volume, reusing the `prodrigestivill/postgres-backup-local` pattern already running on the NAS (it takes a list of databases), with a documented restore that was tried once.
* Summary: `compose.yml` gains `backup` (that image, `@daily`, the five databases and Keycloak's, 7 daily / 4 weekly / 3 monthly) and `backup-gotify` (alpine, a daily `tar` of the Gotify volume mounted read-only, 7 kept), both writing to `CHANGE_ME_BACKUP_DIR` and kept off `edge`. `update.sh [tag]` validates the tag, rewrites the BetterHome image tags (keeping `compose.yml.before-update`), takes a fresh dump through `backup`, then `pull` and `up -d` (migrations first). `restore.sh <database> <dump>` accepts only the six BetterHome database names, checks the gzip, drops and recreates the database and loads the dump. README: Update, Backups, Restore, and the backup folder permission. `make test-nas` also requires the backup service, every database in its list, the read-only Gotify mount and the two scripts.
* Decisions and deviations: backups are Compose services rather than a NAS cron job, so they travel with the stack and need no task scheduler. A live SQLite copy of Gotify can be torn; accepted (README says why). A backup on the same disk is not a backup: the README tells to sync the folder elsewhere. A rollback is "old tag + restore"; there are no down migrations (forward-only, AGENTS §2).
* Verification: with Podman standing in for Docker (a `docker` shim) and a trimmed copy of the real services (Postgres, init-databases, `backup`, `backup-gotify` taken from `compose.yml`): `backup` dumped all six databases; a marked row was destroyed and `restore.sh` brought it back; `restore.sh` refused an unknown name and a non-gzip file, and, with a session open on the database, failed at the drop and left the data intact; `update.sh` rejected a bad tag and, with a valid one, took a new dump and restarted the stack; the tag rewrite checked on the real file (all seven BetterHome images move, third-party images do not); the Gotify archive lists the data folder. `make test-nas` with negative cases (a database missing from the list, a writable Gotify mount) and `make test-docs` pass. Not run: Docker Compose v2 and the real images on the NAS, the full stack update with GHCR images, the restore of Gotify, `make check`.
* Follow-ups: none new.

### T-0114 · Gotify push server on the NAS

* Status: done
* Issue / PR: #126 / (pull request to follow; stacked on #134)
* Depends on: T-0108, T-0109, T-0110
* Spec: §5, §7
* Acceptance criteria: Gotify (`gotify/server`, as the optional `gotify` profile of `deploy/podman-compose.yml`) runs in the NAS stack behind Caddy, reachable from the phone through Tailscale in the way T-0107 decides, with its data in a volume and the admin password a `CHANGE_ME` placeholder edited on the NAS, and the container joining `edge` as `betterhome-gotify`. notifications-service gets `GOTIFY_URL` pointing at it (ADR 0027). Documented: create a Gotify user and application, install the Gotify Android app, point it at the public URL, exempt it from battery optimisation. Verified on the phone: an event (for example an admin marking a member away, or a due reminder) arrives as a push. Until T-0086 exists the application token is registered with `PUT /v1/push-target` (curl command in the README).
* Summary: Gotify and the `GOTIFY_URL` of notifications-service were already in `deploy/nas/compose.yml` (T-0108); this task verified them and documented the use. New: `redir /gotify /gotify/ permanent` in the Caddyfile (without it `https://<host>/gotify` fell through to the other site, and the web UI needs the slash), three more static checks in `make test-nas` (the redirect, `GOTIFY_URL`, the data volume), and a "Push notifications (Gotify)" section in `deploy/nas/README.md`: create the Gotify application and users, install the Gotify Android app against `https://<host>/gotify`, battery and Tailscale advice, register the token with `PUT /v1/push-target` (curl, until T-0086), and how to send a test event with the service client.
* Decisions and deviations: Gotify stays on the `/gotify` path (ADR 0029) because it works there; ADR row amended. Each person who wants pushes needs a Gotify user and application (ADR 0027): one shared admin account is fine for one phone. No change to the services.
* Verification: the NAS stack run locally (local images, throwaway Caddy with `tls internal` importing the snippet): Gotify's UI, its static assets (relative links), `/gotify/health` and its API (401 without credentials, 200 with, 401 with a wrong password) work under `/gotify/`; an application and a client created through the API; a user registered the application token with `PUT /api/notifications/v1/push-target` (200); a WebSocket on `wss://<host>/gotify/stream` upgraded (101); an event posted to `/api/notifications/v1/internal/notifications` with a service token produced the notification and, within a second, the message on the WebSocket and in Gotify's message list with the expected title, text, priority 5 and the `betterhome::push` extras. A browser-style WebSocket with the same `Origin` upgraded, a foreign `Origin` got 403. `/gotify` redirects (301) to `/gotify/`, `/gotifyx` is not claimed. `make test-nas` with negative cases for the three new checks. Not verified: the Gotify Android app on a phone (battery behaviour, the server URL with a path, push after the phone sleeps), Docker Compose v2 and a real Caddy and Tailscale certificate (T-0110), pulling the Gotify image on the NAS.
* Follow-ups: T-0086 replaces the curl registration; `make nas-smoke` (T-0112) checks `/gotify/health`.

### T-0115 · App: server URL entered in the app

* Status: done
* Issue / PR: #127 / (pull request to follow; stacked on #133)
* Depends on: T-0107
* Spec: §1, §7
* Acceptance criteria: The app asks for the server URL on first launch (typed or pasted; a QR code if cheap), stores it, and derives from it the Keycloak issuer and the five service base URLs using the path layout of T-0107. The build-time `--dart-define`s stay as the default so dev, `make run-app` and e2e do not change. Validation and an error state, a way to change the server from the signed-out screen, FR/EN strings, widget tests for the screen and for the URL derivation, goldens and accessibility checks. No host is baked into any build. Needed before any APK is published (T-0116).
* Summary: `ServerConfig` reads what a person types (a bare host means HTTPS, spaces and trailing slashes dropped, plain HTTP only for `localhost`, `127.0.0.1` and `10.0.2.2`, no credentials, query or fragment) and derives the Keycloak issuer and the five service URLs of ADR 0029. `isBetterHomeServer` fetches the OpenID discovery document and requires the expected issuer, so a typo or a wrong server is caught before anything is saved. `ServerSetupScreen` (address field, "Checking…" state, invalid and unreachable errors, "Continue with demo data") is shown by the new `ServerApp` on first launch; it remembers the address in `SharedPreferences`, builds the real stack (`buildStackForServer`) and hands it to `BetterHomeApp`; the sign-in screen shows "Server: <host>" and a "Change server" button that forgets it. `main.dart` keeps the build-time `--dart-define`s as the winning default (dev, `make run-app`, `make e2e` unchanged) and uses `ServerApp` otherwise; FR/EN strings.
* Decisions and deviations: the server check is an addition (the issue did not ask for it) because the NAS setup needs fast feedback on a wrong address and on an issuer mismatch. No QR code (not cheap: needs a camera plugin and permission). Changing the server is possible from the signed-out screen only, so a signed-in user signs out first. The demo option of the old startup is kept on the setup screen. `NAS_HOST` of `make apk` (T-0111) was removed: the APK carries no host, which also makes it publishable. Refactor: the construction of the repositories moved from `main.dart` to `lib/server_stack.dart` and is shared by both startup paths.
* Verification: 9 widget tests of the whole flow (first launch, refused address, unanswering server not remembered, a BetterHome server remembered, next launch straight to sign-in, a stored value that is no longer an address ignored, Change server forgets, demo, French), 8 unit tests of the address rules and the derived URLs plus 4 of the probe (each of them proven to fail on a broken probe and on no persistence); 30 baseline cases (accessibility, 200% text scale, goldens in FR and EN) for the setup screen in four states and the sign-in with a server; `flutter analyze`, `dart format`, all 568 tests; `make apk` (60.7 MB, `INTERNET`, no host inside); `make e2e` on a fresh stack, web target: all journeys passed, including the browser sign-in through Keycloak that goes through the refactored startup. Not verified: on a phone against the NAS (T-0110 and the product owner); Android's rejection of a cleartext address was not exercised.
* Follow-ups: none new.

### T-0116 · Release workflow: signed APK as a GitHub Release

* Status: done
* Issue / PR: #128 / (pull request to follow)
* Depends on: T-0115
* Spec: §1, §10 Phase 6
* Acceptance criteria: A workflow builds a release APK signed with a new BetterHome keystore (created by the product owner and stored as GitHub secrets, never committed) and publishes it as a GitHub Release with exactly one `.apk` asset, the layout the F-Droid repo expects, version taken from `pubspec.yaml`. The certificate fingerprint is recorded for the F-Droid pin (T-0117). Replaces the debug signing of the release build type (`app/android/app/build.gradle.kts`). The Android part of T-0035.
* Summary: `.github/workflows/release.yml` runs on a pushed tag `v*`, fails when the tag is not `v<version>` of `app/pubspec.yaml`, generates the Dart client, builds `flutter build apk --release` with the key decoded from `ANDROID_KEYSTORE_BASE64` into the runner's temp folder (removed after the build), then checks with `apksigner`/`aapt`: not signed by `CN=Android Debug`, `INTERNET` present, application id, no `.ts.net` name. It publishes a release with the single asset `betterhome-<version>.apk` and the certificate's SHA-256 in the notes. `app/android/app/build.gradle.kts` signs with a `release` config read from `ANDROID_KEYSTORE_FILE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` when set, and keeps the debug key otherwise (so `make apk` is unchanged). README documents the release steps.
* Decisions and deviations: a tag trigger rather than every merge, so a version is published on purpose. The keystore is generated by the owner on the dev machine (`~/.betterhome-release/`, outside the repository) and uploaded as secrets; the agent's permission mode blocks writing secrets, so the owner ran it. Third-party actions are the ones already pinned in `check.yml`.
* Verification: with a throwaway keystore (not the release key) `flutter build apk --release` produced an APK whose signer is that key; without the variables `make apk` still signs with the debug key and passes its checks. `make test-docs`. NOT run: the workflow itself (it needs the secrets and a pushed tag), so the first tag is the real test; the real certificate fingerprint is not recorded yet, it appears in the first release's notes and goes into T-0117.
* Follow-ups: record the fingerprint in T-0117 after the first release; the Play Store/iOS parts of T-0035 remain.

### T-0117 · List BetterHome in the F-Droid repository

* Status: todo
* Issue / PR: #129 / —
* Depends on: T-0116
* Spec: §1
* Acceptance criteria: In `Ahzed11/chore-app-fdroid` (public; a separate repository, so this is a pull request there): an `apps.yaml` entry for `Ahzed11/BetterHome`, and `check_signatures.py` changed to pin a signing certificate per app (today one `signing_cert.sha256` applies to every APK, so a second key would block ChoreApp updates too), with ChoreApp's pin and behaviour unchanged and tested. The README table and metadata (name, description, categories, icon) for BetterHome. Merged only after T-0116 has produced a release; verified by adding the repo in an F-Droid client and installing the app.

Out of scope of T-0107 to T-0117, to be filed when wanted: Caddy in the dev compose behind a profile, iOS, the App Store and Play Store listings (T-0035).

### T-0118 · App golden tests render the real date and fail the day after they were made

* Status: done
* Issue / PR: #139 / (pull request to follow)
* Depends on: T-0080
* Spec: AGENTS §5.2 (golden tests), §2 (no direct system clock in domain code)
* Acceptance criteria: The goldens do not depend on the date they run on; no golden image changes.
* Summary: the week strip highlights today and the fake tasks repository stamps due and completion times with `DateTime.now()`, so the 26 chores, home, dialog and toast goldens made on 2026-10-20 failed from 2026-10-21 on, locally and in CI, on every pull request and on `master` (the `app` job, hence `check`). `FakeTasksRepository` takes a `now` clock (default `DateTime.now`), `AppSession` keeps it when profile sync swaps the repository, and `HomeShell` takes `now` like `ChoresScreen` already did. `screens_baseline_test.dart` pins every chores screen and the session to Tuesday 2026-10-20 12:00 UTC, the day the images were made, so they are unchanged.
* Decisions and deviations: the clock went into the fake and the shell, not into a global, following the existing `ChoresScreen.now` parameter. Ids of fake tasks still use the real clock (they must be unique). Other test files that render dates already pass their own `now`.
* Verification: the bug reproduced locally (26 failures, the diff shows two "Today" chips) and on a rerun of a previously green CI run; with the change `flutter test test/screens_baseline_test.dart` passes (336) against the committed images, and `make test-app` passes (545 tests, format and analyze included). Not run: `make check`, `make e2e`; the fix is not proven on a later calendar day (no clock faking on this machine), but nothing the goldens render reads the system date any more.
* Follow-ups: none.

### T-0119 · e2e journeys that need the clock: away reassignment, month-end recap, leaderboard periods, French and English

* Status: in-progress
* Issue / PR: — (suggested: "More time-dependent e2e journeys")
* Depends on: T-0076
* Spec: AGENTS §6.2
* Acceptance criteria: With the test clock of T-0076 (`PUT /v1/test/clock` on each service that needs it): marking a member away reassigns their open tasks, the month-end recap reaches the scoreboard and the notifications, the leaderboard period views change when time passes, and the app is exercised in French as well as English. Each journey resets the clocks it moved.
* Progress: journeys 1 to 3 of 4 done. Journey 3, "French": alice opens the app in French (`initialLocale` fr), completes the profile step and sees the navigation bar in French with no English label, creates a household through the French dialog and opens the Classement tab; the words the journeys read live in a small `_Words` (English and French) that `_openAs` and `_createHousehold` take. The English journeys are unchanged. Journey 2, "leaderboard periods": a quick-logged chore shows in the week, month and all-time views, then the scoring clock moves 40 days ahead and it has left the week and month views (always a different week and month) and stays in all time; the year view is not asserted (40 days may stay in the year). Journey 1, "away": "away" (the admin marks a recurrence assignee away, their open task is dismissed at once, and the next occurrence, after the tasks clock moves 36 hours ahead, goes to the other member). The recurrence setup the time-travel journey used moved into a shared helper (`_startClockHome`). Verified in CI only (no container runtime or Flutter here). Left: month-end recap (scoring and notifications clocks). A shifted scoring clock also lets the month-close job run for earlier households of the same stack; the journeys that follow do not read what it produces. The entry stays `in-progress` until they are done.

### T-0121 · NAS install documentation up to date

* Status: in-review
* Issue / PR: — / (this PR)
* Depends on: T-0108, T-0086, T-0116
* Spec: §7
* Acceptance criteria: The NAS README and the main README describe the real flow, step by step, with Docker Compose (no stale step).
* Summary: NAS README Install rewritten for the UGOS web interface, no SSH (prepare `compose.yml` on a computer with a table of every placeholder, backup folder, `edge` network, Docker app Project, Caddy snippet), with the `docker compose` commands as an alternative; Check it uses the browser; Update and Restore say what the interface offers and what needs SSH. Push registration now uses the app's settings card (T-0086) instead of curl. The main README has a short "Run it on your own server" section and no longer says the GHCR packages are private (they pull anonymously).
* Decisions and deviations: an install script was tried and dropped: the product owner asked for documentation, and uses the UGOS interface without SSH. The menu names are from UGREEN's public pages, not from a NAS, so they are described loosely; restoring a database still needs a shell. ADR 0026's consequence line still says the packages are private; ADRs are history and it was left alone.
* Verification: `make test-nas`, `make test-docs`. Not run: the real NAS, Docker Compose v2, the UGOS Docker app, a real Caddy and Tailscale (T-0110), and the phone (T-0111, T-0114).
* Follow-ups: none.

### T-0122 · NAS Postgres healthcheck fills the log with FATAL lines

* Status: in-review
* Issue / PR: — / (this PR)
* Depends on: T-0108
* Spec: —
* Acceptance criteria: The Postgres healthcheck of `deploy/nas/compose.yml` no longer makes Postgres log an error every 5 seconds.
* Summary: `pg_isready -U betterhome` without `-d` connects to a database named after the user, which does not exist (the stack has `postgres` and `betterhome_<service>`), so Postgres logged `FATAL: database "betterhome" does not exist` on every check while the check itself passed. The healthcheck now passes `-d postgres`. Reported by the product owner from the UGOS Docker app, which showed it as an error.
* Decisions and deviations: only `deploy/nas/compose.yml` changed. `deploy/podman-compose.yml` has the same command line and probably the same log noise; not changed here (surgical).
* Verification: `make test-nas`, `make test-docs`. Not run: the change on the NAS or `pg_isready` against a live Postgres (no container runtime here); the cause is inferred from the check interval matching the log timestamps.
* Follow-ups: the same `-d postgres` in `deploy/podman-compose.yml` if the noise shows there.

### T-0123 · App: pick the household timezone from a list instead of typing it

* Status: in-review
* Issue / PR: — (suggested: "Timezone picker when creating a household") / (this PR)
* Depends on: T-0002
* Spec: §1 (recurrence is computed in the household timezone), §9 (data model: `HOUSEHOLD.timezone`)
* Acceptance criteria: In the create-household screen, the timezone is chosen from a searchable list of IANA zone names (for example `Europe/Paris`) instead of a free text field, so a typo can no longer reach the API. The list is the set of zones the backend accepts; the default is the device's own zone when it is in the list, else `Europe/Paris`. Built from the shared widgets and design tokens (ADR 0021), FR/EN strings in the ARB files, no hard-coded user-facing text. Widget tests for the list (default, search, selection, no match) in French and English, golden and accessibility checks (44 px targets, 200% text scale) for the new screen state, and the `integration_test` journey that creates a household still passes. Editing the timezone of an existing household, if the app offers it, uses the same picker.
* Summary: the create-household screen shows the zone as a field that opens a bottom sheet (`TimezonePickerSheet`): a search box and the list of zones, opened scrolled to the current zone with a check mark on it. The list is `timezoneNames` (`lib/data/timezones.dart`), 418 IANA names taken from the tz database's `zone.tab` plus `UTC`, sorted by code point; `searchTimezones` ignores case and treats a space, an underscore, a hyphen and a slash alike ("new york" finds `America/New_York`). Several words must all match. A search with no match says so. New households start on `Europe/Paris`, as before. FR/EN strings, spec §8.2 has a "Creating a household" paragraph.
* Decisions and deviations: **no device default**: Dart has no way to read the device's IANA zone name without a new plugin (`DateTime.timeZoneName` gives abbreviations such as CET), so the default stays `Europe/Paris` and the dependency was not added; a follow-up can add `flutter_timezone` if wanted. **`America/Coyhaique` is left out** (new in tzdata 2025b): every name was checked against `java.time.ZoneId.of` (all 419 `zone.tab` names plus UTC pass on a current JDK 17), but the services' JDK 21 images may carry older tzdata and a name they cannot parse would break recurrences. The list is bundled in the app, not served by the API, so no contract change. Rows have one fixed height that grows with the text size, which is what lets the list open on the current zone. The profile's own timezone (`profile_sync_screen.dart`, a fixed `Europe/Paris`) is unchanged: it has no screen, so there is nothing to pick; whether it should follow the device is the follow-up above.
* Verification: `make test-app` (format, analyze, 657 tests including the new `timezones_test.dart` (list and search) and `create_household_timezone_test.dart` (picker flow, no match, dismiss, reopen, English and French), and the baseline accessibility, 200% text scale and golden cases of the open picker; goldens `create_household_*` regenerated and `create_household_timezone_picker_*` added). A mutation check: without the scroll to the current zone the "opens scrolled" tests fail. `make test-docs`. `make e2e` (web, fresh stack after `make down`): sign-in journey and all integration journeys passed. Not run: the Android target and a real phone (keyboard over the sheet, the list on a small screen); the first `make e2e` failed only because the local stack still held data from an earlier run (the sign-in driver expects a new user).
* Follow-ups: T-0130 (the server accepts any timezone text); device default through a plugin, to file if wanted.
* Notes for the implementer: `create_household_screen.dart` has a `TextField` with a `'Europe/Paris'` initial value (`_timezone`). `profile_sync_screen.dart` sends a fixed `'Europe/Paris'` as the user's own timezone; decide with the product owner whether the profile timezone gets the picker too (report it, do not guess). Check which zone names the households API validates before choosing the source of the list, and keep a single source of truth for it. The Dart client is generated from `documentation/api/openapi.yaml`; if the list is served by the API, that is a contract change and needs the OpenAPI file, the tests and the spec updated in the same change.

## Loading experience (T-0124 to T-0129)

Planned with the product owner on 2026-10-29. Problem: every tab switch rebuilds the tab (`HomeShell._tabBody` returns a new screen, so a new `State` and a new `Future`), the data is fetched again and the screen shows the text "Loading…"; returning from the household screen blanks the whole shell the same way; after an action the screens call `setState(_reload)`, and `FutureBuilder` then shows "Loading…" over data it already has. Nothing is cached, there are no skeleton widgets, and some screens wait for four requests one after the other (leaderboard).

Decisions of the product owner (2026-10-29): (1) on a revisit the screen shows the last data at once and refreshes it quietly in the background (no spinner, no text swap); (2) once the first tab has loaded, the other tabs are loaded in the background so their first visit is also instant; (3) the cache lives in memory only, nothing about the household is written to the phone (same spirit as T-0072). First loads show skeletons (placeholders with the shape of the real elements) instead of "Loading…".

Order: T-0124 and T-0125 are independent; T-0126 needs both; T-0127 and T-0128 need T-0125; T-0129 (pull to refresh, planned for later) needs T-0126. Rules for every task here: the cache is a concrete class owned by `AppSession`, not a new interface or layer (AGENTS §3); no color, radius or size outside the design tokens (AGENTS §9); strings in the ARB files; tests with delayed fakes, never by sleeping (AGENTS §5.1); `make test-app` and the web e2e (`make e2e`) still pass.

### T-0124 · App: skeleton placeholders instead of "Loading…"

* Status: todo
* Issue / PR: — (suggested: "Skeleton screens on first load") / —
* Depends on: T-0080
* Spec: §8 (design and UX)
* Acceptance criteria: A small set of shared skeleton widgets (a block, a line of text, a circle, and a composition helper) built from the design tokens, in calm neutral tones; a new token only if no existing one fits, and then added to the spec's token table. The pulse is slow and subtle and is switched off when the system asks for reduced motion (`MediaQuery.disableAnimations`). The skeleton of a screen has the layout of the real one so nothing jumps when data arrives: chore cards and the week summary and week strip (Chores and My chores), podium and ranking rows (Leaderboard), list pills and item rows (Lists), notification rows (Inbox), the member and template sections (Household). They replace `Center(Text(l10n.loading))` in these screens and in the `HomeShell` while the households load. The skeleton is one semantics node labelled with the existing `loading` string, its shapes are excluded from semantics. Widget tests per screen (skeleton while the fake is pending, real content after, French and English, the animation off under reduced motion), goldens of each skeleton with the animation pinned to one frame (light mode, ADR 0012), accessibility checks (text scale 200% with no overflow, no touch target below 44 px on screens that show buttons while loading). The error and empty states are unchanged.
* Notes for the implementer: a skeleton is shown only when the screen has no data yet. Once T-0125 exists a revisit shows data, not a skeleton; until then this task alone makes the first load and the current reloads look better but does not remove the flash on revisit. Do not add a package for shimmer unless the dependency is justified (AGENTS §8); a tinted block with an opacity animation is enough.

### T-0125 · App: in-memory read cache that shows the last data and refreshes quietly (Chores tabs first)

* Status: in-review
* Issue / PR: — (suggested: "Show cached data on revisit, refresh in the background") / (this PR)
* Depends on: T-0072
* Spec: §8 (design and UX)
* Acceptance criteria:
  * A concrete cache class owned by `AppSession` (no new interface), keyed by what was asked (kind, user, household and parameters such as the filter or the score period). Reading gives the cached value at once when there is one and starts a refresh in the background; two screens asking for the same key at the same time share one request. A refresh that fails keeps the cached data on screen and shows no blocking error (the next visit retries); with no data the screen shows its error state as today. Only `ApiException` is handled, by name.
  * Nothing is written to disk. The cache is emptied at sign-out, at account deletion and whenever the signed-in profile changes, and every key contains the user id, so one user can never be served another user's data (AGENTS §8).
  * A small helper widget (or state mixin) gives screens `data`, `isFirstLoad`, `isRefreshing` and `error` without a `FutureBuilder` that resets on a new `Future`. A screen that has data never shows a skeleton or "Loading…" again.
  * The Chores and My chores tabs (task list, week summary, admin flag) use it. After the user's own action (complete, dismiss, reassign, revert, quick log, create) the list is updated or refreshed without going back to a loading state: today `setState(_reload)` makes the whole body flip to "Loading…". `HomeShell` keeps tab states alive or reads the cache, so switching tabs and back shows the data in the first frame.
  * The behavior is written in the spec (§8: first load shows a skeleton, a revisit shows the last data then refreshes, nothing is stored on the phone) and an ADR records the decision, the alternatives the product owner discarded (keeping tabs alive only, a fixed time-to-live, saving to the phone) and why memory only.
  * Unit tests of the cache (hit, miss, refresh replaces the value, concurrent reads share one request, failed refresh keeps the value, clear, keys of two users and two households never mix, nothing survives `clear`). Widget tests with a repository whose answers the test releases by hand: tab away and back shows the data in the first frame and the text "Loading…" never appears; a refresh that returns changed data updates the screen; a failing refresh keeps the data. `integration_test` journeys still pass.
* Summary: `lib/state/read_cache.dart` has `ReadCache` (one `ReadEntry` per key: the last answer, and the request in flight, which readers share), the sealed `ReadState` (`ReadLoading`, `ReadLoaded(data, refreshing)`, `ReadFailed(error)`) and `CachedRead`, the handle a screen's `State` holds: it starts a refresh when made, so every visit refreshes, and calls `onChange` when the state changes. `AppSession` owns `readCache`, builds keys with `readKey(kind, householdId:, params:)` (the user id is in every key), empties the cache when the `profile` setter sees another user and when a repository is replaced; `app.dart` empties it in `_leave` (sign-out and account deletion) and for the demo mode's account deletion. `ChoresScreen` (All and My chores) reads its tasks, the members (for the admin flag) and, on My chores, the week summary through it; the `setState(_reload)` after complete, dismiss, revert and quick log became `_refresh()`, so the list no longer flips to "Loading…". ADR 0031 and spec §8.2 record the behavior.
* Decisions and deviations: a `CachedRead` handle in the screen's `State` rather than a helper widget, since Chores reads three things; `ReadState` is a sealed class rather than `data`/`isFirstLoad`/`isRefreshing`/`error` fields, so no `!` is needed. `HomeShell` is unchanged: tabs are still rebuilt on a switch, and read the cache, so their first frame has the data. Members are cached under their own key so other screens can share them (T-0126, T-0128). The shell's own household list still blanks the screen when it reloads after the household screen (T-0126). The first visit still shows the text "Loading…" (T-0124 replaces it with skeletons). Pull to refresh (T-0129) uses `CachedRead.refresh()`.
* Verification: `read_cache_test.dart` (19: states, refresh keeps the old answer, shared requests, a failed refresh, only `ApiException` handled, key isolation between users and households, clear, a request running at clear time, `CachedRead`, the session rules) and `chores_cache_test.dart` (10, with task answers held by the test: first visit loads, return shows the data in the first frame and never "Loading…", the refresh replaces it, a failed refresh keeps it, a failed first visit errors, an action keeps the list on screen, one request for two readers, another user starts empty, My chores keeps its week summary, another household starts empty). A mutation (drop the data when refreshing) fails nine of them. `make test-app` (format, analyze, 716 tests, goldens unchanged) and `make e2e` (web, fresh stack: the sign-in journey and every integration journey passed). Not run: the Android target and a real phone.
* Notes for the implementer: there is no pull-to-refresh anywhere today; adding one is T-0129, so the cache must expose a way to force a refresh of a key. Changes made by housemates appear when the tab is opened again (the refresh runs at every visit); there is no polling, and none is wanted by the product owner for now. Mutations go through the repositories as today; the cache must not become a second source of truth for rules (AGENTS §3, business rules stay in the services).

### T-0126 · App: use the cache on the other screens and keep the shell on screen while it reloads

* Status: todo
* Issue / PR: — (suggested: "Cache for leaderboard, lists, inbox, household") / —
* Depends on: T-0124, T-0125
* Spec: §8
* Acceptance criteria: Leaderboard (board, winners, members, household, per period), Lists (the lists and the items of the selected list), the Inbox and the bell, and the Household screen read through the cache of T-0125 and show a skeleton (T-0124) only on a first load. `HomeShell` keeps showing the current household while the household list reloads after creating a household or returning from the household screen: today it replaces the whole screen with the text "Loading…". Changing the period on the leaderboard, selecting another list, and switching household show cached data for that key at once, or a skeleton when there is none. The bell keeps its dot while it refreshes (no flicker to "no dot"). Widget tests per screen as in T-0125 (first frame after revisit holds the data, no "Loading…"), and the switcher test for two households.
* Notes for the implementer: the leaderboard builds a `FakeScoringRepository` demo setup inside its loading function (`seedDemoIfEmpty`); keep that out of the cached path so the demo mode still works.

### T-0127 · App: load the other tabs in the background after the first tab

* Status: todo
* Issue / PR: — (suggested: "Prefetch the tabs") / —
* Depends on: T-0125
* Spec: §8
* Acceptance criteria: Once the first tab shown has finished loading, the app fills the cache for the other tabs of the selected household in the background, with the data each tab shows first (My chores, the leaderboard for its default period with the winners and members, the lists and the items of the first list, and the unread state of the bell), so the first visit to a tab has data in its first frame in the usual case. Only the selected household is prefetched. A prefetch that fails is dropped without a message (only `ApiException`, handled by name, with a comment saying why); nothing blocks the first tab, and prefetch requests run after the visible tab's own requests. Switching household or signing out cancels what is pending or discards its results, so a late answer never lands under the wrong key. Tests: with a delayed fake, opening Chores triggers the other reads after it has loaded and not before; a failing prefetch changes nothing on screen; a household switch during a prefetch fills the cache of the old household only. Request counts are asserted with a counting fake (no sleeping).
* Notes for the implementer: more requests at startup are the accepted cost (decided on 2026-10-29). Measure it and write the number of requests before and after in the ledger entry.

### T-0128 · App: run independent requests together and ask for each thing once

* Status: todo
* Issue / PR: — (suggested: "Parallel and de-duplicated screen requests") / —
* Depends on: T-0125
* Spec: —
* Acceptance criteria: Requests that do not depend on each other are started together (`Future.wait`): the leaderboard waits for the board, the winners, the members and the household one after the other today, and the week summary of My chores reads the household and then the scoreboard. Members and the household are read once per screen through the cache instead of by each widget (`listMembers` is called by Chores, Leaderboard and Household). First-load time of the leaderboard drops to that of its slowest request; a test with a fake that records start times by ordering (not by sleeping) proves the requests start together. No change to what the screens show.
* Notes for the implementer: keep the services' boundaries as they are (no new aggregate endpoint) unless measurements on the NAS show that the round trips still dominate; that would be a separate task and a contract change (OpenAPI, tests and spec updated together).

### T-0129 · App: pull to refresh on the data screens

* Status: todo
* Issue / PR: — (suggested: "Pull to refresh") / —
* Depends on: T-0126
* Spec: §8
* Acceptance criteria: Pulling down on Chores, My chores, Leaderboard, Lists, the Inbox and the Household screen forces a refresh of what the screen shows (the keys it reads in the cache of T-0125) with the platform's refresh indicator, which ends when the refresh ends. The data stays on screen during the pull and is replaced when the answer arrives: no skeleton, no "Loading…". Screens whose content does not fill the height still accept the pull (an always-scrollable scroll view), including their empty and error states. A failed pull keeps the data and shows the existing app toast (`app_toast.dart`) with a new FR/EN message saying the refresh failed; it is not silent, because the user asked for fresh data (product owner, 2026-10-29). A successful pull shows nothing more than the indicator. Only `ApiException` is handled, by name. Pulling again while a refresh runs does not start a second request (the cache shares it). Widget tests per screen with a hand-released fake (the indicator shows, the new data replaces the old one, a failure shows the toast and keeps the data, French and English), an accessibility check that the screens keep a screen-reader path to refresh (a semantics action or a tooltip-labelled control if the platform's does not expose one), and the goldens are unchanged. Spec §8 mentions the gesture.
* Notes for the implementer: there is no polling and none is planned; this gesture is the way to see a housemate's change without leaving the screen. Tabs hold a scroll view already; check that the tab's `Scrollable` is the one the indicator listens to, since several screens build `Column`s of fixed height. Do not add a package.

### T-0130 · households-service accepts any timezone text

* Status: todo
* Issue / PR: — (suggested: "Validate the household timezone on create and update") / —
* Depends on: T-0002
* Spec: §8 (security: validate all input at the REST boundary), §1 (recurrence in the household timezone)
* Acceptance criteria: Creating or updating a household with a name that `java.time.ZoneId.of` cannot parse is answered 400 (an `ErrorResponse` like the other validation failures), with tests for a valid zone, a typo, blank text and a legal but odd form (an offset such as `+02:00`; decide with the product owner whether offsets are accepted, the app only offers region names). The same for the user's `timezone` on profile sync. The OpenAPI documents say what is accepted.
* Notes: `CreateHouseholdRequest` only has `@NotBlank` on `timezone`. A typo is stored and only fails later, as a 400 "Invalid household timezone" when a recurrence is created (`RecurrenceService`), and the app has no screen to correct a household's timezone. The picker of T-0123 removes the typo from the app, not from other clients.

### T-0131 · App: Lists screen v2

* Status: in-review
* Issue / PR: — (suggested: "Lists screen v2 from the design") / (this PR)
* Depends on: T-0080
* Spec: §4 (shared lists), §8.2 (Lists screen)
* Acceptance criteria: The Lists tab follows the design canvas boards "Lists v2" (with items), "Lists v2 empty" and "Lists v2 options": the household name and title, a row of list pills (the selected one with its open count) with a dashed "new list" pill for admins and a round options button, the open items in one card and the checked ones under "In the basket · N" with an "Uncheck all" button, an add bar docked at the bottom ("Add to <list>…" and a round brand button), the "All stocked up" empty state, and an options bottom sheet (Uncheck all, Remove checked items, and for admins Rename list and Archive list with an "Admin" badge, Archive in coral). FR and EN strings, widget tests, accessibility, 200% text scale and golden cases, the e2e lists journey updated, spec §8.2 updated.
* Summary: `ListsScreen` is restructured: header and pills stay on top, the items scroll, `AddBar` (new, `lib/ui/widgets/add_bar.dart`) is the screen's `bottomNavigationBar`, `showListOptions` (new, `list_options_sheet.dart`) is the sheet. The pills scroll sideways when the lists do not fit. Rename and archive moved from header buttons into the sheet; the reset pill of the header became "Uncheck all" in the basket header and in the sheet. Items are deleted by swiping the row (a `Dismissible`; swiped ids are hidden at once and put back if the request fails) and the row has a "Delete item" custom action for screen readers; the trash icon is gone. "Remove checked items" (new, with a confirmation) deletes each checked item of the list through the existing delete call. The pill count is shown only when some items are open (it said "· 0" before). New empty state replaces the old text. Strings: `renameList` and `archiveList` now read "Rename list" and "Archive list" (they name the sheet rows and the dialog actions); `itemsEmpty` and `addItemHint` were replaced.
* Decisions and deviations: **swipe to delete** was chosen by the product owner (2026-10-29) over keeping the trash icon or dropping single-item delete, because the design has no per-row control; it is not discoverable by sight, a hint is a possible follow-up. **No new token:** the Admin badge reuses `podiumGold` / `podiumGoldInk` (contrast 5.0:1 at 11 px) rather than the design's `#6B4600`. **Reset stays open to every member**, as the design shows (no Admin badge) and the service allows; spec §2 still says admins only, the open question of T-0061. `AddField` is unchanged (the notification settings still use it). Confirmations (uncheck all, remove checked, archive) are kept although the design does not show them: they guard destructive actions. The design's avatar bubble in the add field is a browser overlay in the screenshot, not part of the design. A first version of `AddBar` had a `Container(alignment:)` that took the whole screen height inside the Scaffold's bottom slot and left the list at zero height; the tests caught it.
* Verification: `make test-app` (format, analyze, 687 tests): `lists_screen_test.dart` rewritten (options sheet for member and admin, rename, archive and cancel, swipe delete of open and checked items, swipe to the right does nothing, failed delete brings the row back, remove checked with cancel and confirm, empty and all-checked states, docked add bar, French); baseline accessibility, 200% text scale and goldens for `lists_options_sheet`, `lists_options_sheet_member`, `lists_all_checked` and the regenerated `lists_*` scenarios, English and French. The 200% French case found an overflow in the basket header (button beside the label), now a `Wrap`. `make test-docs`. `make e2e` (web, fresh stack): the sign-in journey and every integration journey passed, the lists one updated for the swipe (as long as the row: the browser window is far wider than a phone, so a short fixed swipe does not reach the 40% threshold), the options sheet and the docked bar; the journey also waits for the list's pill, since the closing dialog's field holds the same text. Not run: the Android target and a real phone (the on-screen keyboard over the docked bar, the real feel of the swipe); the screen-reader action is checked for its presence and name only, not by triggering it.
* Follow-ups: a discoverable hint for swiping (first use or an empty-state line); scrolling a selected pill into view when there are many lists; T-0125 to T-0129 (cache, skeletons, pull to refresh) apply to this screen as to the others.

### T-0132 · Daily recurrence over a daylight-saving gap: flaky property test, maybe an engine defect

* Status: todo
* Issue / PR: — (suggested: "RruleEnginePropertiesTest fails on some seeds over a DST gap") / —
* Depends on: T-0030
* Spec: §3 (recurrence is computed in the household timezone; a local time that does not exist moves forward by the gap, never onto another day)
* Acceptance criteria: `RruleEnginePropertiesTest.aDailyRuleLeavesNoLocalDayOutAndKeepsTheLocalTimeOfDay` passes for every seed, including the one below, and the cause is stated in this entry: either `RruleEngine` keeps the shifted time of a gap day on the following days (a defect: a daily 02:00 rule must be back at 02:00 the day after the gap, spec §3), or the property's model is wrong. A defect gets a failing test first (AGENTS §5) and a fix; a model error gets a corrected property. A fixed regression case (for example `@Example` with the zone and start below) stays in the test class so the case no longer depends on the random generator.
* Notes: seen once in CI on 2026-10-29, `check` of PR #165 (a Flutter-only change, so unrelated), job `backend (tasks-service)`, failing with `the same local time every day ==> expected: <02:00> but was: <03:00>` at `RruleEnginePropertiesTest.java:286`. Shrunk sample: interval 1, zone `America/Adak`, start `2029-03-11T02:00` (the spring-forward moment in that zone). Failing seed `-577492766145996246` (jqwik: `@Property(seed = "...")` reproduces it). The property already skips a day whose start time falls in a gap (`getValidOffsets(...).size() == 1`), so the failing occurrence is a later day, which is why a drift after the gap is suspected, not shown. The test passed on `master` on 2026-10-27 to 2026-10-29 (the random generator did not hit the case), and passed on a rerun of the same commit. Not reproduced locally: the local JDK 17 cannot run the build (JDK 21 is needed, `make doctor`).
