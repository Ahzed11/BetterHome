# AGENTS.md

Instructions for AI agents (and humans) working on this repository. Read this file fully before changing anything. If an instruction here conflicts with a request, say so and ask before proceeding.

## 1. Project in one paragraph

A mobile app (Flutter) for people sharing a home. It spreads recurring chores fairly (round robin), rewards effort with points on a friendly scoreboard, and offers shared checklists. Backend: a set of **Java / Quarkus microservices** (`households`, `tasks`, `scoring`, `lists`, `notifications`) orchestrated on **Red Hat OpenShift** with **managed PostgreSQL**, packaged as container images. Identity and access management are handled by **Keycloak** (OIDC / OAuth2), behind an interface so it can be replaced. Push notifications (FCM / APNs) are sent via a dedicated notification gateway. The [product specification](documentation/project-specification.md) is the **source of truth** for behavior. Code, tests, and spec must always agree.

## 2. Non-negotiable principles

1. **No shortcuts, no hacks.** Solve the real problem. Never silence a failure instead of fixing it.
2. **Keep it simple.** No overengineering: no abstraction, configuration, generic framework or extension point without a present need in the spec.
3. **Surgical changes.** Touch only what the task requires (see section 4).
4. **Thorough testing, always.** Every behavior change ships with tests at the right levels (section 5). The app must be launched and tested automatically (section 6).
5. **The spec decides.** If the spec is ambiguous or wrong, stop and ask. Do not guess business rules.
6. **Keep the task ledger current.** Read `documentation/tasks.md` before starting and update it before finishing (section 12).

### Forbidden (without explicit approval in the task)
- Skipping, ignoring, disabling or deleting tests, or weakening assertions, to make a build pass.

- `@Disabled`, `@Ignore`, `@SuppressWarnings`, or lint suppressions to hide warnings. Fix the cause.

- `NullPointerException` risks, bare `catch (Throwable t)`, or swallow/ignore exception blocks in production Java code. Use strongly typed domain exceptions and `Optional`.

- Dart `!` null assertions and `dynamic` where a proper type is possible, and `// ignore:` comments.

- Mocking our own code to avoid testing it (mock only true external boundaries, see 5.1).

- Committing secrets, tokens, service account files, realm export files with passwords, or real personal data.

- `git commit --no-verify`, force-pushing shared branches, or editing already-applied database migrations.

- TODO/FIXME comments without a linked issue. Hard-coded user-facing strings. Calling system clock directly in domain code.


## 3. Architecture and technology

| Area | Decision |
|---|---|
| Client | Flutter (mobile first, web later). Clean, reusable code across platforms |
| Backend | Java 21 / Quarkus **microservices architecture**: independent services for `households`, `tasks`, `scoring`, `lists`, and `notifications`. HTTP on REST Jackson/RESTEasy Reactive with `quarkus-oidc` for token validation |
| Database | PostgreSQL (managed, EU). Per-service database isolation. Schema migrations via **Flyway** (SQL files, forward-only) |
| Platform | **Red Hat OpenShift Platform** (OCP) using OpenShift Deployments, Routes, ConfigMaps, Secrets, Keycloak Operator, and Health Probes |
| Auth | **Keycloak** (OIDC / OAuth2 JWT bearer tokens), behind the `AuthVerifier` interface. Token validation via Quarkus OIDC security layer. Our own `USER.id` is the only identity used in tables. Keycloak `sub` (subject UUID) is stored once as `auth_subject` |
| Push | Push Notification Gateway behind the `PushSender` interface, fed by an **outbox table** written in the same transaction as the change |
| Scheduling | Quarkus Scheduler / Quartz loop on Postgres per service: claims due rows with `FOR UPDATE SKIP LOCKED`, one transaction per job |
| Time | `Clock` interface / CDI bean. All timestamps in UTC. Recurrence computed in the household timezone |
| Packaging | Container images built via Quarkus container extensions / Jib, deployed locally with Podman / `oc` CLI or OpenShift Local (CRC) |
| API style | REST + OpenAPI, with Quarkus SmallRye OpenAPI and a generated Dart client for the app |

Rules:
- **Service boundaries are strict.** Each microservice owns its PostgreSQL database/schema and exposes a small REST interface. No microservice reads another service's database directly. Communication between microservices happens over REST/gRPC interfaces secured with Keycloak tokens / service accounts.

- **Interfaces only at declared boundaries** (`AuthVerifier`, `PushSender`, `Clock`). Do not add new interfaces or layers "for flexibility".

- **Business rules live in domain code, not in REST resources or SQL triggers.** Resource endpoints parse, authorize (via `@RolesAllowed` or custom security checks), delegate, and map exceptions.

- **Database integrity is enforced by the database too:** foreign keys, `NOT NULL`, unique constraints, enums or `CHECK` constraints for statuses and reasons.

- **12-factor cloud-native application:** configuration from environment variables / OpenShift ConfigMaps & Secrets, stateless containers, JSON logs on stdout (`quarkus-logging-json`), `/health/live` and `/health/ready` SmallRye Health endpoints, graceful shutdown on SIGTERM. Migrations run as init containers or dedicated one-shot deployment jobs on OpenShift, never at app startup in production.


### Proposed repository layout (confirm before creating)

```

backend/
build.gradle.kts / pom.xml (Maven/Gradle multi-module project)
services/
households-service/
tasks-service/
scoring-service/
lists-service/
notifications-service/
common-domain/
app/            Flutter app (OIDC sign-in with the `oidc` package, ADR 0020)
deploy/         Helm / Kustomize manifests for OpenShift, Keycloak Realm exports, Containerfiles, local Podman scripts
documentation/  project-specification.md, tasks.md (ledger), decisions/ (ADRs), api/openapi.yaml
AGENTS.md

```

## 4. Making changes surgically

- **Smallest diff that fully solves the task.** Read the surrounding code and follow its conventions.

- **No drive-by changes:** no unrelated refactors, renames, formatting sweeps, dependency bumps or "cleanups". If you spot a problem outside the task, report it in the summary instead of fixing it.

- **One concern per change** (one logical commit or pull request). Mixed changes are rejected.

- **Do not reformat files you did not change.** Run the formatter only on touched files, and it must produce no extra diff.

- **Reuse before adding.** Search for an existing function, widget, or query before writing a new one.

- **Delete what you made obsolete,** but only what your change made obsolete.

- **Update in the same change:** tests, the task ledger (`documentation/tasks.md`), the spec (if behavior changed), the OpenAPI file (if the API changed), and ARB translation files (if UI text changed).

- **Migrations are forward-only and additive.** Never edit a Flyway migration that has been applied or merged. A schema fix is a new migration script. Prefer expand-then-contract for breaking changes.

- **Before editing, state the plan** in two or three lines: what files, what behavior, what tests. After editing, summarize the diff and anything you noticed but did not touch.


## 5. Testing: thorough, no exceptions

A change is not done until tests prove it. Bug fixes start with a failing test that reproduces the bug.

### 5.1 Backend (Java / Quarkus)
- **Unit tests** (`@QuarkusTest` or pure JUnit 5) for domain logic: points calculation (on time vs late), round-robin selection (skips away and left members, cursor behavior), RRULE next-run computation across timezones and DST, reversion outcomes, permission rules.

- **Property-based / Invariant tests** (using Jqwik / JUnit) for invariants: round robin never picks an ineligible member, the ledger sum equals awarded points minus reversed points, scores never go negative.

- **Integration tests against real PostgreSQL** using **Quarkus Dev Services / Testcontainers**. **Never mock the database.** Each test runs in an isolated schema or rollback transaction. Flyway migrations are applied from scratch in integration tests.

- **Scheduler tests** use a mocked/fake `Clock` bean: spawn, supersede, reminders, away reassignment, "everyone away", month-end recap. Include concurrency tests with multiple replicas to prove `SKIP LOCKED` prevents double-spawn.

- **Authorization tests for every endpoint:** each role (admin, member, non-member, left member, user of another household) gets an explicit allowed or forbidden assertion (`@TestSecurity` or Quarkus REST assured checks with `@TestSecurity(user = "...", roles = {...})` or `OidcSecurity`). A user from household A must never read or change household B.

- **Transaction tests (`@Transactional`):** a failure mid-job leaves no partial state (no spawned task without its supersede, no points without a completion).

- **External boundaries** (`AuthVerifier`, `PushSender`) use CDI `@Alternative` / `@Priority` or Keycloak Testcontainers / WireMock in-memory fakes in tests.

- **API contract:** responses and requests are validated against `documentation/api/openapi.yaml`. CI fails on drift. Every real answer is checked, so a field the API starts returning without documenting it always fails.

- Tests assert behavior and outcomes, not implementation details. No thread sleeping: control time with the clock.


### 5.2 Frontend (Flutter)
- **Unit tests** for view models, repositories, formatters and the derivation of member colors.

- **Widget tests** for every screen and reusable widget: loading, empty, error and populated states, in French and English.

- **Golden tests** for the design-system widgets and key screens, to protect the look and feel (light mode only for now).

- **Accessibility checks:** minimum 44 px touch targets, text contrast, semantic labels, text scaling up to 200% with no overflow.

- **Integration tests** (`integration_test`) for the user journeys in 6.2.

- Repositories talk to the API through the generated client containing bearer authorization headers. Test them against a fake server or the real backend, never by hand-built JSON that can drift from the contract.


### 5.3 Quality gates (all must pass before a change is done)
`mvn spotless:check` / `./gradlew spotlessCheck`, `mvn checkstyle:check` / PMD / SpotBugs, `mvn test` (JUnit 5 + Quarkus Test), `dart format --set-exit-if-changed`, `flutter analyze` (no warnings), `flutter test`, the end-to-end suite (6.2), and a clean build of container images. Coverage must not drop. New domain code is expected to be fully covered, and mutation testing (`Pitest`) is run periodically on the `scoring` and `tasks` microservices.

Dependency vulnerability check tools (`mvn dependency-check:check` or OWASP Dependency Check plugin) run inside `make test-backend`. CI installs tools at pinned versions. Both fetch vulnerability advisory databases and **fail rather than report a clean result when they cannot check**: an audit that passes because it could not reach its database is not a check (section 4).

## 6. Run it and test it automatically

Agents must not claim something works without having run it.

### 6.1 Commands (define in a `Makefile` or `justfile`, keep this table accurate)

| Command | Purpose |
|---|---|
| `make up` | Start local OpenShift cluster (CRC / OpenShift Local) or Podman Compose stack (Postgres, Keycloak instance, microservices) |
| `make migrate` | Apply Flyway migrations across all microservice databases |
| `make seed` | Load a demo household with two members and sample data |
| `make test-backend` | Format, dependency audit, lint, Quarkus unit and integration tests |
| `make test-app` | Analyze, unit, widget and golden tests |
| `make openapi` | Regenerate `documentation/api/*-openapi.yaml` from the annotated code; review and commit the diff (`decisions/0015-openapi-generated-from-code.md`) |
| `make update-goldens` | Regenerate the golden images (Linux only; `decisions/0012-goldens-compared-on-one-platform.md`) |
| `make test-docs` | Resolve documentation's relative links and its ADR/ledger references |
| `make test-policy` | Require every dependency unvulnerable and verified against policies |
| `make mutation` | Mutation testing with Pitest on the pure domain code of `tasks` and `scoring` (run periodically, not part of `make check`; `decisions/0023-property-and-mutation-testing.md`) |
| `make test-guard` | Prove the generated-client guard fails when the document or the client is broken |
| `make e2e` | Full microservice stack up on OpenShift/Podman, app launched on the selected target (`E2E_TARGET=web` default, or `android`), integration tests run against Keycloak Auth |
| `make check` | Everything above, as in CI |
| `make down` | Stop and clean containers/cluster resources |

### 6.2 End-to-end: launch the real app against the real stack
- `make e2e` boots the microservice stack on OpenShift/Podman (including Keycloak realm import), applies Flyway migrations, launches the Flutter app on the target chosen with `E2E_TARGET` (`web` in headless Chrome by default, or `android` on a headless emulator; `decisions/0018-e2e-target-is-selectable-web-first.md`), authenticates against Keycloak, and runs the `integration_test` suite against the deployed OpenAPI Routes and PostgreSQL DBs. Notification delivery uses a fake push gateway endpoint.

- Required journeys, each mapped to a spec rule: sign up and create a household; invite and join; admin creates a template and a recurrence; scheduler spawns a task and assigns round robin; assignee completes it (on time and late); quick-log a manual task and undo; dismiss with confirmation; admin reverts with a reason and the assignee sees it; mark a member away and watch tasks reassign; leaderboard period views; checklist create, check, delete, reset; household switcher with two households; French and English.

- Time-dependent flows (due dates, month end) run with a controllable clock exposed only in the test environment.

- CI runs `make check` on every pull request. If you cannot run the e2e suite in your environment, say so explicitly. Do not report success.


## 7. Domain rules that must never break

These are summarized from the spec. When they conflict with code, the spec wins.

- **Points ledger is append-only.** Scores are computed from it. Reversals are negative rows that link to their reversion record. Scores never go below zero.

- **Tasks are snapshots** of their template (title, emoji, description, points, late points). Editing a template never changes past tasks.

- **Points go to the assignee,** even if an admin completed the task. `completer_id` is audit only.

- **Completion:** assignee or admin. On time earns `points`, after `due_at` earns `late_points`.

- **Dismissal** is irreversible, never awards points, and is allowed for the assignee (own task) or an admin (any task). UI confirmation is required.

- **Spawning a recurrence** and dismissing the previous open recurrence task (`superseded`) happen in **one transaction**. The superseded assignee is notified.

- **Round robin** skips members who left or are away. Fixed assignee away falls back to round robin. If everyone is away, the task is created and dismissed as `nobody_available`.

- **Away:** setting a member away dismisses their open tasks (`assignee_away`). Only admins can do it. If the tasks service cannot be reached, the away change fails.

- **Reversion** (admin, reason required): only on `done` tasks. Manual task becomes `reverted`. Recurrence task reopens with its original `due_at`, or is dismissed as `reverted_overdue` if that date has passed. Notify only if reopened with a future date.

- **Manual tasks** are created already done, assigned to the creator, with full points and no due date.

- **Archiving a template** stops its recurrence and leaves existing tasks alone.

- **A household always has at least one active admin.** The last admin must hand over or delete the household before leaving.

- **Lists:** every list is a checklist. Items award no points. Deleting items is a soft delete.


## 8. Security, privacy and data

- Authorize **every** request: validate OAuth2 JWT via Keycloak public keys, verify authenticated user, active membership, then role. Deny by default.

- Never log access tokens, refresh tokens, passwords, emails, push tokens or message content. Logs are structured JSON (`quarkus-logging-json`) with request IDs / MDC tracing context.

- Push payloads carry minimum data (IDs and short text), never sensitive details.

- Validate all input at the REST boundary (`@Valid`, `@NotNull`). Use parameterized SQL / Hibernate ORM with Panache / Agroal connection pooling only. No string-concatenated queries.

- Account deletion triggers user deletion/anonymization in Keycloak via Admin REST API and anonymizes the user's history across microservices. The ledger stays consistent.

- Dependencies: justify each new Java library or extension, prefer Quarkus native extensions, and run dependency check tools.


## 9. Conventions

- **Language:** code, comments, commits, docs in English. UI in French and English through externalized ARB files. No hard-coded user-facing strings.

- **Java / Quarkus:** strongly typed exceptions, `Optional` return types for nullable queries, clear CDI dependency injection (`@ApplicationScoped`), `quarkus-oidc` for token processing, small functions, JavaDoc on public service interfaces.

- **Dart:** null-safe, strict analysis options, widgets driven by design tokens in `documentation/project-specification.md` section 8. No colors, radii or font sizes hard-coded in screens.

- **Design:** calm, rounded, soft green. Overdue is soft coral, never alarming red. No dark mode yet (tokens are semantic so it can come later).

- **Commits:** Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`), small and focused. The message explains why.

- **Decisions:** significant technical choices get a short ADR in `documentation/decisions/` (context, decision, consequences).

- **Docs:** if you change behavior, you change `documentation/project-specification.md` in the same change.


## 10. Definition of done

A task is done only when all of these are true:
- [ ] The behavior matches the spec, and the spec is updated if it changed.

- [ ] The diff is minimal and touches nothing unrelated.

- [ ] `documentation/tasks.md` is updated (status, summary, decisions, verification, follow-ups).

- [ ] Tests exist at every relevant level and fail without the change.

- [ ] `make check` passes, including the e2e suite, with no skipped tests or suppressed warnings.

- [ ] The app was actually launched on OpenShift/Podman with Keycloak integration and the feature exercised.

- [ ] Authorization, error and empty states are handled and tested.

- [ ] Strings are translated (FR and EN) and accessibility checks pass.

- [ ] No secrets, no TODOs without issues, no dead code introduced.

- [ ] The summary lists what changed, what was tested, and anything noticed but intentionally left alone.


### Merging

Since 2026-10-14 the product owner lets agents merge the pull requests they opened, so merging no longer waits for a human. An agent merges only when all of these hold:

- the `check` job is green on the pull request's latest commit (never merge pending or red, never bypass a failing job). **Exception:** when the diff touches only Markdown files (`*.md`), CI checks nothing about it, so the agent merges without waiting for it; a diff with any other file waits for CI as above;
- the pull request is mergeable without conflicts, and the ledger entry matches the code (section 12);
- the definition of done above is met, and what could not be verified (for example the Android target) is written in the ledger and the pull request;
- it is a merge commit (`gh pr merge --merge`), the history on `master` keeps one merge per pull request;
- it is the agent's own pull request, or one the product owner asked it to merge. An agent does not merge someone else's pull request on its own initiative.

**While GitHub Actions is unavailable** (for example the minutes limit is reached; the product owner said so on 2026-10-14), the local run replaces the CI result: the agent runs `make check` and `make e2e` on the pull request's latest commit, from a clean checkout of the branch, and writes the commands and results in the pull request description before merging. A failing or skipped step blocks the merge exactly as a red job would, and "the run on `master`" below becomes the same local run on `master`. When Actions is available again this paragraph no longer applies; the product owner says when.

After merging, the agent checks that the run on `master` is green, deletes nothing it did not create, and tells the product owner what was merged. If `master` turns red, fixing or reverting it comes before any new work. Branch protection (T-0053) stays a repository setting for the product owner; this rule does not replace it.

Some agent environments block `gh pr merge` unless a permission rule allows it; the product owner adds that rule in the agent's settings.


### Choosing the next task

When an agent finishes a task (merged, ledger updated, `master` checked), it does not wait to be told what comes next. It reads the open GitHub issues and the ledger (section 12) and picks the next task itself:

1. Take the lowest-numbered milestone that still has open work, and inside it the task whose `Depends on` entries are all `done`. Prefer one that unblocks others.
2. Skip `blocked` and `dismissed` entries, entries that say a product decision is needed first, and tasks another agent has `in-progress`.
3. Mark it `in-progress` in the ledger, state the plan (section 4) and proceed with the same rules as any task.

It stops and asks only when the next step needs a product decision, the spec is ambiguous or wrong (section 11), something needs a permission or a secret it does not have, or nothing eligible is left. Parallel agents each pick different tasks and respect the single local stack (only one agent runs `make up` or `make e2e` at a time).


## 11. When unsure

Ask. Prefer a short question over a wrong assumption. Never invent a business rule, and never choose a shortcut because the proper path is slower.

## 12. Task ledger (`documentation/tasks.md`)

The ledger is the shared memory between agents and between sessions: what was done, what is left, and what future agents need to know. **Read it before starting. Update it before finishing.** An agent that skips either step has not finished the task.

### Relationship with other sources
- **GitHub issues** are the unit of work and the source of truth for assignment and discussion.

- **The spec** (`documentation/project-specification.md`) is the source of truth for behavior. The ledger must never contradict it. If it does, the spec wins and the ledger is corrected.

- **The ledger** is a readable index of work plus implementation notes. It does not replace issues, the spec or ADRs. A durable technical decision belongs in an ADR, and the ledger entry links to it.


### Rules
1. **Read first.** At the start of every task, read the ledger to see the state of the project, dependencies and earlier decisions.

2. **Update in the same pull request as the code.** The ledger on `main` then always matches the code on `main`. A status is never changed in a separate "bookkeeping" commit.
3. **Edit only your own entry** (plus the status of tasks you unblock). Never reorder, rewrite or delete other agents' entries.
4. **Status must be backed by evidence.** Never mark a task `done` unless `make check` passed, the app was launched, and the acceptance criteria are met. Record what was run.
5. **Be brief and factual.** Write what a future agent needs: decisions, deviations from the issue, gotchas, and how to verify. No step-by-step logs, no copied code, no speculation.
6. **Report discovered work, do not do it.** Anything noticed outside the task scope becomes a new `todo` entry under "Discovered", with a suggested issue. This keeps changes surgical.
7. **Nothing sensitive:** no secrets, tokens or personal data.
8. **Keep it bounded.** Completed entries older than 30 days move to `documentation/tasks-archive.md`, keeping one line each.

### Statuses
`todo` → `in-progress` → `in-review` → `done`. Also `blocked` (always with the reason and the blocking task) and `dismissed` (always with the reason).

### Entry format

```

### T-0042 · Verify Keycloak JWT tokens in the API

* Status: in-review
* Issue / PR: #42 / #57
* Depends on: T-0040
* Spec: §2, §9 (auth)
* Summary: what was implemented, in two to five lines.
* Decisions and deviations: choices made, and any difference from the issue.
* Verification: commands run and journeys exercised (for example `make check`, e2e journey "sign up").
* Follow-ups: new tasks discovered (IDs or suggested titles).

```
IDs are sequential and never reused.

### Who updates what
- **Planner:** adds new entries as `todo`, with the issue number, dependencies and acceptance criteria.

- **Implementer:** sets `in-progress` when starting, `in-review` when the PR is ready, and fills Summary, Decisions, Verification and Follow-ups.

- **Reviewer:** rejects the PR if the entry is missing, inaccurate, or claims more than the code and tests prove.

- **Merge** is what makes `done` true: the PR sets `done` only when it is the final change for the task.


### Merge conflicts
Parallel agents will touch this file. Keep each entry self-contained, append new entries at the end of their section, and on conflict rebase and keep both sides. If conflicts become frequent, propose splitting into one file per task under `documentation/tasks/` with a generated index. Do not do this unprompted.

