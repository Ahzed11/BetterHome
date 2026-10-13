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

## In progress

_(none)_

## Todo

_(none)_

## Discovered

### T-0003 · Reassign open tasks when a member is marked away

* Status: todo
* Issue / PR: —
* Depends on: T-0002, Phase 2 tasks domain
* Spec: §2 Away, §3.3 Reassignment
* Acceptance criteria: Admin sets away in households-service; open tasks for that assignee are reassigned round-robin (tasks-service), with notification outbox later.

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
