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

## In progress

_(none)_

## Todo

_(none)_

## Discovered

### T-0003 · Reassign open tasks when a member is marked away

* Status: todo
* Issue / PR: —
* Depends on: T-0007
* Spec: §2 Away, §3.3 Reassignment
* Acceptance criteria: When an admin sets away in households-service, call tasks-service `POST .../tasks/reassign-away/{userId}` (endpoint exists) so open tasks move to eligible members.

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
