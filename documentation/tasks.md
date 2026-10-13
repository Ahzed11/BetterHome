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

* Status: todo
* Issue / PR: —
* Depends on: T-0009
* Spec: §7 service boundaries, §3.4
* Acceptance criteria: tasks-service calls scoring-service award/reverse over REST with service or user token; scoring-service resolves membership via households-service HTTP client; keep in-memory doubles for Quarkus tests.

### T-0012 · Dismiss open tasks when a future-dated away period starts

* Status: todo
* Issue / PR: —
* Depends on: T-0003
* Spec: §2 Away, §3.3 Away
* Acceptance criteria: A member marked away with a future `away_from` has their open tasks dismissed (`assignee_away`) when that instant arrives. Needs a households scheduler (claims due rows with `FOR UPDATE SKIP LOCKED`, one transaction per job) and a way to call tasks-service without a user token, which means a write-capable service role that ADR 0014 does not grant yet; decide that first. The job must also mark what it has handled so a restart does not repeat it.

### T-0013 · Services reject every real Keycloak user: principal is not the `sub` UUID

* Status: todo
* Issue / PR: —
* Depends on: T-0001
* Spec: §2, §9 (auth), AGENTS §3 (Auth)
* Acceptance criteria: `OidcAuthVerifier` expects the principal name to be the Keycloak `sub` UUID, but quarkus-oidc defaults to `preferred_username`, so with a real token every service answers 401 "Authentication required". Set `quarkus.oidc.token.principal-claim=sub` in each service (found during T-0008; reproduced with the demo user from `deploy/keycloak/README.md` and fixed at runtime only), and add a test that fails without it.

### T-0014 · Invitation endpoints return 404 on a running server

* Status: todo
* Issue / PR: —
* Depends on: T-0002
* Spec: §2 (invitations)
* Acceptance criteria: `POST/GET /v1/households/{id}/invitations` answer 404 "Resource Not Found" when the service runs, although they are listed in the route table and the service-level tests pass. `InvitationResource` is rooted at `@Path("/v1")` and appears to lose to `HouseholdResource` at `/v1/households`. Add an HTTP-level test that fails today (create then accept an invitation through REST) and fix the routing.
