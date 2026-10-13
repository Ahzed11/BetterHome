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

Milestones in delivery order (vertical slice first). A milestone is reached when its exit criterion holds and its tasks are `done`. T-0003 and T-0008 are in review and close before M1.

* **M1 · Real sign-in works** — T-0013, T-0014, T-0036. Exit: A Keycloak user can call every service, and invitations work over HTTP.
* **M2 · Toolchain, local stack, gates, CI** — T-0015, T-0016, T-0017, T-0005, T-0018. Exit: `make up` runs all five services; `make check` enforces AGENTS §5.3 and runs in CI on every pull request.
* **M3 · Services wired for real** — T-0010, T-0019. Exit: No in-memory gateway or ledger client left in main code; one app contract describes every endpoint.
* **M4 · App vertical slice on the real stack** — T-0020, T-0006, T-0021, T-0022. Exit: The app signs in through Keycloak and runs households, chores and leaderboard against `make up`; `make e2e` runs in CI.
* **M5 · Lists (spec Phase 5)** — T-0023, T-0024. Exit: The Groceries tab journey passes end to end.
* **M6 · Notifications** — T-0025, T-0026, T-0027, T-0028, T-0012. Exit: Every notification type in spec §5 reaches a fake push gateway in the user's language, honoring preferences.
* **M7 · Spec completeness and polish (spec Phase 6)** — T-0029, T-0030, T-0031, T-0032, T-0033. Exit: Every rule in spec §2–§9 is implemented and covered by an end-to-end journey.
* **M8 · Deploy and launch** — T-0004, T-0034, T-0035. Exit: The stack runs on OpenShift with migrations as Jobs, and signed store builds are produced. Blocked until an OpenShift cluster is available; until then Podman Compose is the target platform.

## Todo

### T-0015 · Developer toolchain: Flutter and the Android emulator

* Status: in-review
* Issue / PR: #8 / #36
* Depends on: —
* Spec: AGENTS §5.3, §6
* Acceptance criteria: Install and pin the Flutter SDK and the Android SDK with a headless emulator image on the development machine. OpenShift Local and `oc` are not needed: there is no cluster for now and Podman Compose is the target platform (see T-0004). Document versions and setup in README. Add `make doctor` that fails when a required tool or version is missing (JDK 21 via jbang, Podman and its socket, `podman compose` provider, Flutter, emulator).
* Summary: `tooling/versions.env` pins Flutter 3.47.7 (Dart 3.13.5), Android command-line tools 13114758, platform android-35, build-tools 35.0.0, the `google_apis` x86_64 image and the `betterhome-test` AVD, with SHA-256 checksums for both downloads. `tooling/install-dev-tools.sh` installs them idempotently under `$HOME` (uses `sudo dnf` only when system packages are missing, accepts the Android SDK licenses). `tooling/dev-env.sh` puts them on `PATH`; `make doctor` (`tooling/doctor.sh`) fails on anything missing; the Makefile now finds jbang, Flutter and the Android tools by itself. `tooling/start-emulator.sh` starts the headless AVD. README documents the setup. A second commit adopts the `pubspec.lock` and `analysis_options.yaml` changes that Flutter 3.47.7 writes on first use.
* Decisions and deviations: OpenShift Local / `oc` dropped from scope (decision of 2026-10-13). Installed with the `claude` account's sudo authorization granted by the product owner for this purpose; the script itself never stores a password. The emulator is installed and the AVD created, but the emulator process does NOT yet stay up on this VM: see T-0045. Lockfile and analyzer excludes are tool-written consequences of pinning the SDK, committed separately so they can be reviewed apart.
* Verification: `make doctor` passes (13 checks) and fails with exit 1 and six `MISSING` lines when the SDK path is wrong. `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze` (no issues) and `flutter test` (13 tests) pass with Flutter 3.47.7 from `app/`. NOT verified: an emulator boot (crashes, T-0045), `make test-app`/`make check` as a whole, e2e, CI.
* Follow-ups: T-0045 (emulator crash).

### T-0016 · `make up` and `make seed` run the full local stack

* Status: in-review
* Issue / PR: #9 / #38
* Depends on: T-0013, T-0014, T-0015
* Spec: §7, AGENTS §6.1, ADR 0003
* Acceptance criteria: Podman Compose starts Postgres, Keycloak (realm import) and all five services as containers built with the Quarkus container extension; services get their DB URL, OIDC settings and service-account secrets from environment variables (no committed secrets: realm secrets injected at import). `make migrate` runs Flyway per service as one-shot containers. `make seed` creates a demo household with two members and sample templates through the public APIs. `make down` cleans everything. Verified by a scripted smoke check.
* Summary: `deploy/podman-compose.yml` now runs Postgres, Keycloak and the five services (prod profile, images from the existing `Dockerfile.jvm` files over the fast-jar in `target/quarkus-app`; no new Quarkus extension or library). `make up` packages the jars, starts Postgres and Keycloak, runs `make migrate`, starts the services, then runs `deploy/smoke.sh`. `make migrate` (`deploy/migrate.sh`) now runs the official Flyway image once per service database on the Compose network (real checksums; replaces the hand-rolled psql loader). `make seed` (`deploy/seed.sh`) creates users alice and bob with kcadm, then uses password-grant tokens to call `PUT /v1/me`, create "Demo Home", invite and accept, and add three templates; rerunning skips what exists. `make smoke` waits for `/q/health/ready` on :8081-:8085 and sends one Keycloak token to every service. `make down` removes containers, volumes and built images.
* Decisions and deviations: Issuer: Keycloak runs with `KC_HOSTNAME=http://localhost:8180` and `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true`, so `iss` is always `http://localhost:8180/realms/betterhome` while services fetch discovery and JWKS at `keycloak:8180`; issuer validation stays on. Secrets: only the local-dev placeholder already in the realm file (`local-dev-only-change-me`), supplied to tasks-service through `OIDC_SERVICE_CLIENT_SECRET` (overridable from the host environment); demo users use the password `demo`, created at seed time, never in the realm file. Services start after migrations, which is why `make up` orders it that way. Compose project name stays `betterhome` (fixed), so two stacks cannot run at once. Kept Flyway outside the services (`migrate-at-start=false` unchanged).
* Verification: see the PR description for the commands run. Not run: Flutter, e2e, CI. Limit found: after completing a task as the assignee, `GET :8083/v1/households/{id}/scoreboard` returns 403 because scoring-service has no real membership gateway yet and tasks-service does not call scoring over HTTP (T-0010); points on the scoreboard cannot be shown until then.
* Follow-ups: T-0010 (scoring wiring, needed for the scoreboard step), T-0046 (#37: image build in `make check`/CI, Dockerfile EXPOSE).

### T-0017 · Backend quality gates: format, lint, coverage

* Status: in-review
* Issue / PR: #10
* Depends on: T-0015
* Spec: AGENTS §5.3
* Acceptance criteria: `make test-backend` runs spotless check, checkstyle (or PMD/SpotBugs) and JaCoCo with a coverage floor that cannot drop, then the Quarkus tests. Existing violations are fixed in the same change, no suppressions. Gate failures fail `make check`.
* Summary: Root `backend/pom.xml` now runs, in `validate`, Spotless (google-java-format 1.28.0, AOSP style, unused imports removed) and Checkstyle 10.21.4 with `backend/config/checkstyle.xml`, and in `verify` JaCoCo report + line-coverage floor. Checkstyle encodes AGENTS §2 Forbidden: `@SuppressWarnings`, `@Disabled`/`@Ignore`, `catch (Throwable)`, empty catch blocks, TODO/FIXME without an issue number, system-clock calls (only `SystemClock` and tests exempt), star and unused imports. Services use `quarkus-jacoco`; a Maven Enforcer rule fails the build when the coverage file is missing. `.mvn/jvm.config` opens the compiler modules google-java-format needs. Floors (line coverage, just below measured): households 0.82, tasks 0.70, scoring 0.62, lists 0.90, notifications 0.90, common-domain 0.09.
* Decisions and deviations: Checkstyle only (no PMD/SpotBugs), since the AGENTS gate lists them as alternatives; revisit if needed. Existing violations fixed: a formatting sweep of 44 files (own commit, no behavior change) and one `@SuppressWarnings` in `RecurrenceSpawnService` that was unnecessary and is removed. google-java-format 1.37.0 does not run on this JDK, hence the 1.28.0 pin. The floors are measured values, not targets: raise them as tests land. The dependency audit stays in T-0005. Coverage tooling is not wired into the aggregate `make check` beyond `make test-backend`.
* Verification: `./mvnw -B clean verify` in `backend/` on JDK 21 passes. Negative checks run and reverted: each Checkstyle rule trips on a deliberately bad file (including `@Disabled` and unused import in tests); a floor of 0.99 fails scoring with "Rule violated"; a clean build without tests fails with "No coverage data". `make`, Flutter, e2e and CI were not run.
* Follow-ups: T-0037 (common-domain direct unit tests and a higher floor).

### T-0018 · CI: run `make check` on every pull request

* Status: todo
* Issue / PR: #11
* Depends on: T-0016, T-0017
* Spec: AGENTS §6.2
* Acceptance criteria: GitHub Actions workflow with pinned tool versions runs `make check` (docs, backend, app, policy, guard) on pull requests and on `master`. Podman or Docker available for Testcontainers. The e2e job is added by T-0021.

### T-0019 · One app contract: merge the generated per-service OpenAPI documents

* Status: todo
* Issue / PR: #12
* Depends on: T-0010
* Spec: §7 API style, ADR 0006, ADR 0007
* Acceptance criteria: `documentation/api/openapi.yaml` is produced by merging the per-service documents generated in T-0005 (app-facing operations of all services; operations tagged `internal` excluded) and is guarded the same way (a test fails when the committed aggregate differs from the merge). Operation ids and schema names must stay unique across services.

### T-0020 · Generated Dart client replaces hand-written repositories

* Status: todo
* Issue / PR: #13
* Depends on: T-0019, T-0005
* Spec: ADR 0006, AGENTS §2, §5.2
* Acceptance criteria: Generate the Dart client from `openapi.yaml` into the gitignored `generated/` folder; app repositories use it with bearer headers. Remove hand-written JSON parsing and `dynamic`. Repository tests run against a fake server built from the contract, not hand-built JSON. `make test-guard` proves generation fails when the document or client is broken.

### T-0021 · `make e2e`: real app on an emulator against the real stack

* Status: todo
* Issue / PR: #14
* Depends on: T-0006, T-0016, T-0015
* Spec: AGENTS §6.2
* Acceptance criteria: `make e2e` boots the stack, applies migrations, launches the app on a headless Android emulator, signs in through Keycloak and runs `integration_test` journeys. Adds a controllable clock exposed only in the test environment and a fake push gateway endpoint. CI job added to the T-0018 workflow. Each later feature task adds its journey here.

### T-0022 · Golden and accessibility baseline for existing screens

* Status: todo
* Issue / PR: #15
* Depends on: T-0015
* Spec: AGENTS §5.2, spec §8
* Acceptance criteria: Golden tests (light mode, Linux per ADR 0012) for design-system widgets and the households, chores and leaderboard screens. Accessibility checks: 44 px touch targets, text contrast, semantic labels, 200% text scaling without overflow, in FR and EN.

### T-0023 · lists-service: checklists, items and bulk reset

* Status: todo
* Issue / PR: #16
* Depends on: T-0008, T-0016
* Spec: §4, §2 permissions, §6.2 LIST/ITEM
* Acceptance criteria: Flyway schema for LIST and ITEM with constraints; admins create, rename and archive lists; any member adds, edits, checks, unchecks and soft-deletes items (who and when); bulk reset unchecks all items. Membership through households internal endpoints with a service account (ADR 0014). Authorization matrix tests for every endpoint (admin, member, non-member, left member, other household). OpenAPI updated.

### T-0024 · App: Groceries tab

* Status: todo
* Issue / PR: #17
* Depends on: T-0023, T-0020
* Spec: §4, §8.2
* Acceptance criteria: Fourth bottom tab with list overview and item screen: create, check, uncheck, delete, reset (admin actions hidden for members). FR/EN strings, loading/empty/error/populated widget tests, goldens. e2e journey "checklist create, check, delete, reset".

### T-0025 · notifications-service core: inbox, preferences, rendering

* Status: todo
* Issue / PR: #18
* Depends on: T-0016
* Spec: §5, §6.2 NOTIFICATION/PREFERENCE
* Acceptance criteria: notifications-service owns NOTIFICATION and PREFERENCE. Internal ingest endpoint (service role) accepts typed events with an idempotency key; it renders FR/EN text server-side in the recipient's language, applies per-type preferences, stores the notification and hands it to `PushSender`. App-facing API: list notifications, mark read, read/update preferences. ADR records the event contract and ownership.

### T-0026 · Outbox relays into notifications-service

* Status: todo
* Issue / PR: #19
* Depends on: T-0025
* Spec: §5, AGENTS §3 Push
* Acceptance criteria: tasks-service relays its outbox to notifications-service instead of calling `PushSender` directly; households-service gets an outbox for marked-away and invitation events. Relays claim rows with SKIP LOCKED, deliver at least once, and are idempotent on the receiving side. Tests cover retries and duplicate delivery.

### T-0027 · Real push delivery: FCM and APNs

* Status: todo
* Issue / PR: #20
* Depends on: T-0025
* Spec: §5, AGENTS §8
* Acceptance criteria: Device-token registration API, FCM/APNs implementation of `PushSender` in notifications-service, minimal payloads (IDs and short text), invalid-token cleanup. Tests use an in-memory fake of the vendor boundary; e2e uses the fake push endpoint from T-0021.

### T-0028 · App: notification inbox, preferences and push registration

* Status: todo
* Issue / PR: #21
* Depends on: T-0025, T-0027, T-0020
* Spec: §5
* Acceptance criteria: Inbox screen with read state, per-type preference toggles, push permission prompt and token registration. FR/EN, widget and golden tests, e2e journey.

### T-0029 · Scoring in household time and automated month end

* Status: todo
* Issue / PR: #22
* Depends on: T-0010
* Spec: §3.4, §5
* Acceptance criteria: Week/month/year windows computed in the household timezone; a scheduled job closes each month at the household's local boundary (SKIP LOCKED, one transaction per household) and records the winner. App shows the recap and confetti once per user. Clock-controlled tests across timezones and DST.

### T-0030 · Scheduler concurrency and invariant tests

* Status: todo
* Issue / PR: #23
* Depends on: T-0017
* Spec: AGENTS §5.1
* Acceptance criteria: Concurrency tests with several scheduler instances prove no double spawn or double close. jqwik property tests: round robin never picks an ineligible member, ledger sum equals awarded minus reversed points, scores never go negative. Pitest run on tasks and scoring documented.

### T-0031 · App UX per spec §8: switcher, quick-log undo, overdue tone

* Status: todo
* Issue / PR: #24
* Depends on: T-0020
* Spec: §8.1, §8.2, §3.3
* Acceptance criteria: Household switcher at the top; "+ I just did…" quick-log with single-tap logging and 5-second undo; overdue shown in soft coral with "still +N"; reverted tasks show their reason to the assignee. Widget, golden and e2e coverage (quick-log and undo, revert seen by assignee, household switcher with two households).

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

* Status: in-review
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

* Status: in-review
* Issue / PR: #2
* Depends on: T-0001
* Spec: AGENTS §5.1 (API contract), ADR 0006 / 0007 / 0015
* Acceptance criteria: Changed from the original issue (OWASP audit and generated-client guard) by the product owner: the OpenAPI documents are generated from annotations in the Java code instead of being written by hand, and the build fails when the committed documents differ from what the services serve. The OWASP audit moves to T-0038 (parked); the generated-client guard stays with T-0020.
* Summary: All 45 operations of the five services carry `@Operation` (stable `operationId`), `@APIResponse` (success, error and 401/403/404 codes with the `ErrorResponse` body) and `@Tag`; a bearer scheme is configured once in `common-domain`. Untyped `Map` answers became records (`ServiceInfo`, `DismissedCount`, `ReassignedCount`, `CelebrationSeen`) with identical JSON. `documentation/api/<service>-openapi.yaml` are generated and committed; the hand-written `openapi.yaml`, `tasks-`, `scoring-` and `households-internal-` files are removed (internal operations are tagged `internal` in the households document). Each service has `OpenApiContractTest` (shared `OpenApiContract` helper in the `common-domain` test-jar). `make openapi` regenerates. ADR 0015.
* Decisions and deviations: Contract is per service until T-0019 merges it into `documentation/api/openapi.yaml`, so AGENTS §5.1 and ADR 0006/0007 still name a file that does not exist yet. Comparison is on parsed trees (formatting never fails it); regenerate with `make openapi`. Operations with any explicit `@APIResponse` must declare their 2xx too (SmallRye drops the default). `LocalTime` fields carry an explicit string schema because the default example is read as a base-60 number by YAML parsers. `make` runs need `jbang` on `PATH` so the Makefile finds JDK 21.
* Verification: `make test-backend` (Spotless, Checkstyle, all tests, coverage floors, contract tests) passes on JDK 21. Negative checks run and reverted: adding an undocumented field to a response makes `OpenApiContractTest` fail with "no longer matches"; deleting a committed file fails with "does not exist"; regenerating twice produced identical files. The first households run exposed a parse problem that generation alone hid (fixed). Flutter, e2e and CI were not run.
* Follow-ups: T-0038 (OWASP audit, parked), T-0039 (check real answers against the contract), T-0019 (aggregate), T-0020 (Dart client + `make test-guard`).

### T-0006 · Keycloak AppAuth in Flutter and e2e household journeys

* Status: todo
* Issue / PR: #3
* Depends on: T-0002
* Spec: §2, §9, AGENTS §6.2
* Acceptance criteria: App authenticates via Keycloak (PKCE); e2e covers sign-up/create household/invite/join against the real stack.

### T-0008 · HTTP MembershipGateway from tasks-service to households-service

* Status: in-review
* Issue / PR: —
* Depends on: T-0007
* Spec: §7 service boundaries
* Acceptance criteria: Replace in-memory membership directory with token-propagating REST client; keep test double for Quarkus tests.
* Summary: households-service exposes read-only `GET /v1/internal/households/{id}/members` and `/settings` for the `service` realm role. tasks-service's `HttpMembershipGateway` calls them through `HouseholdsClient` with its own client-credentials token (`quarkus-oidc-client`), for request handlers and background jobs alike. `InMemoryMembershipGateway` moved to `src/test` as a CDI alternative. Households unreachable maps to 503 (`TaskException.ServiceUnavailable`). New Keycloak client `betterhome-tasks-service` and realm role `service`; ADR 0014; `documentation/api/households-internal-openapi.yaml`.
* Decisions and deviations: Deviates from "token-propagating": forwarding the user's token cannot serve scheduler jobs, so one service-account token is used everywhere (ADR 0014); no `/members/me` endpoint was added. Tasks verifies the user's token, then asks households whether that subject is a member. The service role can read any household, so only trusted services may hold it. Realm secret is the same local-dev placeholder as `betterhome-api`; real secrets come from `OIDC_SERVICE_CLIENT_SECRET`. The fake households server in tests returns hand-written JSON; the contract is checked against the real service only by the live run below until T-0005 adds drift checks.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (households 20 tests incl. `InternalHouseholdResourceTest` role matrix; tasks 28 tests incl. `HttpMembershipGatewayTest`). Live: real Keycloak 26 realm import yields a service token with `realm_access.roles=[service]`; households-service in dev mode answers internal endpoints 401 (no token) / 403 (user token) / 200 / 404; tasks-service in dev mode created and listed a template for the real admin and returned 403 for a service account and an unknown household. The live run needed `-Dquarkus.oidc.token.principal-claim=sub` (see T-0013). `make` is not installed, so `make check`, Flutter checks and e2e were not run.
* Follow-ups: T-0013, T-0010 (scoring reuses the pattern), compose does not start the services yet (T-0004).

### T-0010 · HTTP PointsLedgerClient and scoring MembershipGateway

* Status: in-review
* Issue / PR: #4 / #34
* Depends on: T-0009
* Spec: §7 service boundaries, §3.4
* Summary: tasks-service writes the ledger through `HttpPointsLedgerClient` (REST to scoring award/reverse with its service token); scoring-service resolves membership through `HttpMembershipGateway` (households internal members endpoint with its own service token). The in-memory doubles moved to `src/test` as `@Alternative @Priority(1)` beans. New Keycloak client `betterhome-scoring-service` (service role) in the realm export; secret via `OIDC_SERVICE_CLIENT_SECRET`, local-dev placeholder only in `%dev`/realm. Scoring contract regenerated (`adminUserId`, 503); scoring coverage floor raised 0.62 to 0.75.
* Decisions and deviations: Award and reverse now require the `service` role (ADR 0014 addendum); household admins and members get 403 there, and award no longer checks membership because tasks authorizes the user first. Reverse carries `adminUserId` (the caller is no longer the admin) and scoring verifies via households that it is an active admin. Any scoring failure maps to `TaskException.ServiceUnavailable` (503), or Conflict on a 409; the call is the last step of the task transaction, so a failed award rolls the completion back and a failed reversal leaves the task done. Known gap: scoring commits before tasks commits, so a failed local commit leaves points without a done task (T-0040).
* Verification: `make test-backend` (all services green, JaCoCo floors met, spotless and checkstyle clean); `make openapi` regenerated scoring only. Live run with real Keycloak 26, Postgres 16 and households/tasks/scoring in dev mode: bob completes a task and the real scoreboard shows 5 points; a user token calling award directly gets 403 (also for the admin); alice reverts it and the scoreboard returns to 0; with scoring stopped, completion answers 503 `service_unavailable` and the task stays open with no done tasks. Not run: Flutter, `make e2e`, households-down live case (covered by tests only).
* Follow-ups: T-0040.

### T-0012 · Dismiss open tasks when a future-dated away period starts

* Status: todo
* Issue / PR: #5
* Depends on: T-0003
* Spec: §2 Away, §3.3 Away
* Acceptance criteria: A member marked away with a future `away_from` has their open tasks dismissed (`assignee_away`) when that instant arrives. Needs a households scheduler (claims due rows with `FOR UPDATE SKIP LOCKED`, one transaction per job) and a way to call tasks-service without a user token, which means a write-capable service role that ADR 0014 does not grant yet; decide that first. The job must also mark what it has handled so a restart does not repeat it.

### T-0013 · Services reject every real Keycloak user: principal is not the `sub` UUID

* Status: in-review
* Issue / PR: #6
* Depends on: T-0001
* Spec: §2, §9 (auth), AGENTS §3 (Auth)
* Acceptance criteria: `OidcAuthVerifier` expects the principal name to be the Keycloak `sub` UUID, but quarkus-oidc defaults to `preferred_username`, so with a real token every service answers 401 "Authentication required". Set `quarkus.oidc.token.principal-claim=sub` in each service (found during T-0008; reproduced with the demo user from `deploy/keycloak/README.md` and fixed at runtime only), and add a test that fails without it.
* Summary: `common-domain/src/main/resources/META-INF/microprofile-config.properties` sets `quarkus.oidc.token.principal-claim=sub`, so all five services pick it up from the module that owns `OidcAuthVerifier`. New shared test fixture `RealOidcTestResource` (common-domain test-jar) enables token validation with a generated RSA key and signs Keycloak-shaped tokens; each service has `RealTokenAuthTest` calling `/v1/meta` with a token whose `sub` is a UUID and `preferred_username` is `demo`.
* Decisions and deviations: One property in `common-domain` instead of five copies (deviation from the issue text); service `application.properties` can still override it. Root `pom.xml` manages the `common-domain` test-jar, which each service depends on in test scope. The test failed before the fix in households-service (200 with an empty `authSubject`); the other four share the same code path and were run only with the fix.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (all services pass). Live on real Keycloak 26 + Postgres 16 with households and tasks in dev mode and no runtime override: demo user's `/v1/meta` returned the Keycloak `sub`, profile sync 200, household create, template create 201, no token 401, unknown household 403. `make` checks beyond `verify` (spotless, checkstyle, audit), Flutter and e2e were not run.
* Follow-ups: T-0036.

### T-0014 · Invitation endpoints return 404 on a running server

* Status: in-review
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

* Status: in-review
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

* Status: in-review
* Issue / PR: #32 / PR_PLACEHOLDER
* Depends on: T-0005
* Spec: AGENTS §5.1 (API contract)
* Acceptance criteria: Quarkus tests validate every real response (status, headers, body) against `documentation/api/<service>-openapi.yaml` with a request/response validator and fail when an answer has a field or status the document does not declare; additional properties are forbidden in schemas. T-0005 keeps the document equal to the code; this keeps the answers equal to the document.

### T-0040 · Make ledger awards idempotent per task

* Status: todo
* Issue / PR: #33
* Depends on: T-0010
* Spec: AGENTS §7 (points ledger, completion)
* Acceptance criteria: Awarding the same task and reason twice appends one row (unique constraint plus idempotent endpoint), or tasks writes awards through an outbox in the same transaction. A commit failure in tasks after scoring committed can no longer leave points for an open task or double-award on retry. Tests cover the retry.

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
