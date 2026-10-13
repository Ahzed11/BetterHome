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

## Todo

_(none)_

## Discovered

### T-0003 · Reassign open tasks when a member is marked away

* Status: in-review
* Issue / PR: —
* Depends on: T-0007
* Spec: §2 Away, §3.3 Reassignment
* Acceptance criteria: When an admin sets away in households-service, call tasks-service `POST .../tasks/reassign-away/{userId}` (endpoint exists) so open tasks move to eligible members.
* Summary: `MembershipService.setAway` fires `MemberAway`; `AwayReassignment` observes it after commit and calls tasks-service through the `TasksClient` REST client (`TASKS_SERVICE_URL`), forwarding the admin's bearer token. No call when `away_from` is in the future.
* Decisions and deviations: Synchronous, no retry; a failed call is logged and does not undo the away change. A future-dated away is not reassigned when it begins (see T-0012). If every other member is away, tasks-service answers 409 and the tasks stay with their assignee; the spec does not define this case, so a spec decision is needed (T-0012). Not functional end to end until T-0008, because tasks-service membership data is still the in-memory directory.
* Verification: `./mvnw -B verify` in `backend/` on JDK 21 (all services pass; `AwayReassignmentTest` covers token forwarding, future-dated away, tasks-service failure, rejected non-admin). `make` is not installed here, so `make test-backend`, `make check`, the Flutter checks and e2e were not run; the app was not launched against Keycloak.
* Follow-ups: T-0012.

### T-0004 · OpenShift / CRC deploy manifests for microservices

* Status: todo
* Issue / PR: —
* Depends on: T-0001
* Spec: §7, ADR 0003
* Acceptance criteria: Deployments, Routes, ConfigMaps/Secrets, health probes, and migration Jobs for each service on OpenShift Local or a cluster.

### T-0005 · OWASP dependency-check and OpenAPI client drift guard

* Status: todo
* Issue / PR: —
* Depends on: T-0001
* Spec: AGENTS §5.3, ADR 0006 / 0007
* Acceptance criteria: `make test-policy` and `make test-guard` fail closed when advisories or OpenAPI/client drift cannot be verified.

### T-0006 · Keycloak AppAuth in Flutter and e2e household journeys

* Status: todo
* Issue / PR: —
* Depends on: T-0002
* Spec: §2, §9, AGENTS §6.2
* Acceptance criteria: App authenticates via Keycloak (PKCE); e2e covers sign-up/create household/invite/join against the real stack.

### T-0008 · HTTP MembershipGateway from tasks-service to households-service

* Status: todo
* Issue / PR: —
* Depends on: T-0007
* Spec: §7 service boundaries
* Acceptance criteria: Replace in-memory membership directory with token-propagating REST client; keep test double for Quarkus tests.

### T-0010 · HTTP PointsLedgerClient and scoring MembershipGateway

* Status: todo
* Issue / PR: —
* Depends on: T-0009
* Spec: §7 service boundaries, §3.4
* Acceptance criteria: tasks-service calls scoring-service award/reverse over REST with service or user token; scoring-service resolves membership via households-service HTTP client; keep in-memory doubles for Quarkus tests.

### T-0012 · Away reassignment: future start, retries, and nobody left

* Status: todo
* Issue / PR: —
* Depends on: T-0003, T-0008
* Spec: §2 Away, §3.3 Reassignment
* Acceptance criteria: Decide and implement (1) reassignment when a future `away_from` arrives, (2) reliable delivery of the households → tasks call (outbox or retry) instead of a logged best-effort call, (3) what happens to open tasks when no other member is eligible; the spec must define (3) first.
