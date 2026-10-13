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

## Todo

### T-0002 · Phase 1 households domain (users, memberships, invitations, away)

* Status: todo
* Issue / PR: —
* Depends on: T-0001
* Spec: §2, §10 Phase 1
* Acceptance criteria: registration/join flows, household CRUD, roles, invitations, away reassignment hooks as specified.

## Discovered

_(none yet)_
