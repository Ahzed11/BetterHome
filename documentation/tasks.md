# Task ledger

Shared memory for agents and humans. Read before starting; update before finishing. See AGENTS.md §12.

## In progress

### T-0001 · Phase 0 foundations (monorepo, Quarkus, Flyway, Keycloak)

* Status: in-progress
* Issue / PR: (none yet)
* Depends on: —
* Spec: §7, §10 Phase 0
* Acceptance criteria:
  * Monorepo layout matches the spec (`backend/`, `app/`, `deploy/`, `documentation/`)
  * Five Quarkus services build and expose `/q/health/*` plus authenticated `/v1/meta`
  * Flyway baseline migrations exist per service DB; `make migrate` applies them
  * Podman Compose runs Postgres (five DBs) and Keycloak with realm import
  * `AuthVerifier`, `Clock`, `PushSender` seams live in `common-domain`
  * ADRs 0001–0007, 0011–0013 present; OpenAPI stub checked in
  * `make test-backend` and `make test-docs` pass
* Summary: (fill on completion)
* Decisions and deviations: (fill on completion)
* Verification: (fill on completion)
* Follow-ups: (fill on completion)

## In review

### T-0002 · Phase 1 households domain (users, memberships, invitations, away)

* Status: in-review
* Issue / PR: —
* Depends on: T-0001
* Spec: §2, §10 Phase 1
* Summary: households-service now syncs users from the auth subject (`PUT /v1/me`), creates/lists/updates/soft-deletes households, manages memberships (roles, leave with last-admin guard), invitations (create/list/accept with email match), and away status. Authorization is membership-based, not Keycloak realm roles.
* Decisions and deviations: Local user rows are upserted via `PUT /v1/me` (email/names from the client after Keycloak login) rather than reading JWT claims in the verifier. Invitation TTL defaults to 7 days (not specified). Away does not trigger task reassignment here (tasks-service owns that).
* Verification: `make test-docs`; `make test-backend` (households Phase 1 tests + other services). e2e / app launch not run.
* Follow-ups: T-0003 (away → open-task reassignment in tasks-service).

## Todo

_(none)_

## Discovered

### T-0003 · Reassign open tasks when a member is marked away

* Status: todo
* Issue / PR: —
* Depends on: T-0002, Phase 2 tasks domain
* Spec: §2 Away, §3.3 Reassignment
* Acceptance criteria: Admin sets away in households-service; open tasks for that assignee are reassigned round-robin (tasks-service), with notification outbox later.
