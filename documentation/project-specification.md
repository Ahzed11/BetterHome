# Household App: Project Specification

Working title: TBD · Status: Draft v2 · Complements the "Intent and Goals" document

---

## 1. Overview

A mobile app (Flutter) for people who share a home. It spreads recurring chores fairly, rewards effort with points on a friendly scoreboard, and offers shared checklists. It is sold as a product (the pricing model and monetization are not decided yet): users download the app, create an account, then create or join households.

**Goals:** fair distribution of chores, lower mental load, recognition of effort, satisfying friendly competition (podium, monthly confetti), balanced scores as proof that it works.

**Principles:** admins set the rules and members act within them; no penalties; spontaneous contributions are rewarded; corrections always carry a reason; no adult/child distinction for now.

---

## 2. Users, households, and roles

- A user has an account (email and password authenticated via Keycloak) and can belong to several households (for example, a student flat and the family home). The UI lets the user choose which household to view.
- A membership links a user to a household with a role: `admin` or `member`. A household can have several admins.
- Members join by invitation (email, token, expiry, role).
- Leaving sets `left_at`, so history and scores are kept. The last admin must promote someone else or delete the household before leaving.
- **Away status:** an admin can mark a member away (`away_from`, optional `away_until`). Away members are skipped by assignment.

### Permissions
| Action | Admin | Member |
| :--- | :---: | :---: |
| Create, edit, archive templates and recurrences | ✅ | ❌ |
| Create, rename, archive lists | ✅ | ❌ |
| Invite members, change roles, set away status | ✅ | ❌ |
| Reassign a task | ✅ | ❌ |
| Revert a done task (reason required) | ✅ | ❌ |
| Complete a task | ✅ (any task) | ✅ (own tasks) |
| Dismiss a task (with confirmation) | ✅ (any task) | ✅ (own tasks) |
| Log a spontaneous (manual) task | ✅ | ✅ |
| Add, edit, check, uncheck, delete list items | ✅ | ✅ |
| Reset a list (uncheck all items) | ✅ | ❌ |

---

## 3. Tasks and points

### 3.1 Templates and recurrence
- A task template (admin-defined) has a title, description, points (on time), `late_points` (fixed amount when completed after the deadline), and a default due offset.
- A template may have one recurrence: an RRULE schedule, start and end dates, and an assignment mode: `fixed` (one person) or `round_robin`.
- Recurrence is computed in the household timezone. When the local time of an occurrence does not exist (daylight saving gap), it moves forward by the length of the gap, but never onto another calendar day: it then stays on its own day, at the last second.
- Archiving a template stops its recurrence. Existing tasks are unaffected, since tasks are snapshots of the template.
- Every task is based on a template.

### 3.2 Assignment (round robin)
- Each recurrence points to a rotation holding a cursor (`last_assigned_user_id`). For now, each chore has its own rotation. The schema allows sharing a rotation across chores later.
- The next assignee is the next eligible member after the cursor, in a stable order (membership ID). Members who have left or are away are skipped.
- If a fixed assignee is away, that occurrence falls back to round robin.
- If everyone is away, the task is created and immediately dismissed (`nobody_available`) so history shows the chore was skipped.

### 3.3 Task lifecycle
| Status | Meaning |
| :--- | :--- |
| `open` | To be done by the assignee |
| `done` | Completed, points awarded |
| `dismissed` | Closed with no points. Final, cannot be reopened |
| `reverted` | A completed manual task cancelled by an admin |

- **Spawning:** the scheduler creates a task at each occurrence. In the same transaction, it dismisses any still-open recurrence task of the same template (`superseded`) and notifies its assignee.
- **Completion:** by the assignee or an admin. Points always go to the assignee. The person who clicked is stored as `completer_id` for audit. Completing before `due_at` awards points, after it awards `late_points`.
- **Dismissal:** by the assignee on their own task or by an admin on any task. The UI asks for confirmation, since it is irreversible. Dismissed tasks never award points. Reasons: `manual`, `superseded`, `nobody_available`, `reverted_overdue`, `assignee_away`.
- **Reassignment:** admin only, round robin among eligible members.
- **Away:** when a member is marked away, their open tasks are dismissed (`assignee_away`, recorded against the admin who set the member away) instead of being reassigned. If tasks-service cannot be reached, marking the member away fails and nothing is saved. Later assignment (round robin, fixed-assignee fallback) ignores away members. When `away_from` is in the future, nothing happens at the request; when that instant arrives, a households scheduler dismisses the member's open tasks (`assignee_away`, recorded against the admin who set the period) exactly once. If tasks-service cannot be reached then, the dismissal is retried on the next run. A period that was cleared, ended or whose member left before it began dismisses nothing.
- **Manual tasks:** a member logs a chore they just did ("I took out the garbage"). It is created already done, assigned to its creator, with full points and no due date. It does not affect recurring tasks.
- **Reversion (admin, reason required):**
  - The completion's points are reversed with a negative ledger entry.
  - Manual task: becomes `reverted`.
  - Recurrence task: reopened to `open` with its original `due_at`. If that date has passed, it is dismissed (`reverted_overdue`) instead.
  - The assignee sees the reason in the UI, on the task, for as long as the task is not done again (the task carries the reason of its latest reversion), and gets a push only if the task was reopened with a future deadline.
  - Only `done` tasks can be reverted. A task can be completed and reverted several times, each reversion kept as a record.

### 3.4 Points and scoreboard
- Points live in an append-only ledger (`POINT_TRANSACTION`). Reasons: `task_completed`, `task_completed_late`, `reversal`, `manual_adjust`.
- Scores never go negative: reversals equal what was awarded, and manual adjustments are guarded.
- Scoreboard is all-time, with week, month, and year views and browsing of past months, computed from the ledger and scoped per household. Weeks (Monday to Sunday), months and years are cut at the household's local midnight, so daylight saving changes make a period an hour longer or shorter. It also shows a shared effort bar (each member's share of the period's points) and a hall of past winners.
- Podium for the top three, friendly in tone. At the end of each month (at the household's local month boundary), the month is closed automatically and every member sees its recap with a confetti celebration, once (the winner is named, and told so if it is them). The winner is the member with the most points in the month (a tie goes to the lowest user id); a month in which nobody scored has no winner and no recap.

---

## 4. Shared lists

- Every list is a checklist: items can be checked and unchecked. Checking awards no points.
- Admins create, rename, and archive lists. Any member adds, edits, checks, unchecks, and deletes items (soft delete, with who and when).
- A bulk reset action unchecks all items (useful for packing lists). Only admins can reset a list; a member gets 403.
- Items of an archived list are frozen: adding, editing, checking, unchecking, deleting and resetting answer 409. Reading them stays allowed.
- Checking an already checked item (or unchecking an unchecked one) is a no-op, so the first completer is kept.

---

## 5. Notifications

- Push notifications are delivered through a self-hosted Gotify server (ADR 0027). A user receives them by registering the application token of their own Gotify application (`PUT /v1/push-target`); without one they get the in-app inbox only. The data model keeps a channel field for later email or in-app channels.
- Types: task assigned, reassigned, due reminder, overdue, dismissed, superseded, reverted (only if reopened), marked away, invitation.
- Reminder default: on the day of the task at 08:00 household time. Configurable per household (`reminder_days_before`, `reminder_time`). `due_reminder_sent_at` prevents duplicates.
- Users can toggle each notification type. Messages are rendered server-side in the user's language, with minimal personal data in the payload.

---

## 6. Data model

### 6.1 Relationships
`USER` joins `MEMBERSHIP` in a `HOUSEHOLD`. `HOUSEHOLD` owns `LIST` (contains `ITEM`), `TASK_TEMPLATE` (defines `TASK_RECURRENCE`, which spawns `TASK`), and `ROTATION` (assigns `TASK`). `TASK` receives `TASK_REVERSION` and records `POINT_TRANSACTION`. Notifications, activities, and monthly recaps attach to `USER` and `HOUSEHOLD`.

### 6.2 Entities
| Entity | Key fields and notes |
| :--- | :--- |
| `USER` | `auth_subject` (Keycloak sub UUID, unique), `email` (synced copy), names, language, timezone, `deleted_at` |
| `HOUSEHOLD` | `name`, `timezone`, `reminder_days_before`, `reminder_time`, `created_by`, `deleted_at` |
| `MEMBERSHIP` | `user`, `household`, `role`, `joined_at`, `left_at`, `away_from`, `away_until`, `away_set_by`, `away_tasks_dismissed_at` |
| `INVITATION` | `household`, `email`, `role`, `token` (unique), `expires_at`, `accepted_at` |
| `LIST` / `ITEM` | List: `title`, `created_by`, `archived_at`. Item: `title`, `position`, `creator`, `completer`, `completed_at`, `deleted_at`, `deleted_by` |
| `TASK_TEMPLATE` | `title`, optional `emoji`, `description`, `points`, `late_points`, default due offset, `archived_at`. No categories |
| `ROTATION` | `household`, optional `name`, round-robin cursor |
| `TASK_RECURRENCE` | `template` (unique), `rotation`, `RRULE`, assignment mode, fixed assignee, start and end, `last_generated_at`, `next_run_at` |
| `TASK` | Snapshot of template fields (including emoji), origin (recurrence or manual), status, assignee, completer, dismissal fields, `due_at`, `due_reminder_sent_at`, `completed_at` |
| `TASK_REVERSION` | `task`, admin, reason, points reversed, resulting status, timestamp |
| `POINT_TRANSACTION` | `household`, `user` (always the assignee), `task`, `reversion`, signed points, reason |
| `NOTIFICATION` / `PREFERENCE` | Per user and household: type, JSON payload, `read_at`. Preferences per type and channel |
| `ACTIVITY_LOG` | `household`, actor, entity type and ID, action, timestamp |
| `MONTHLY_RECAP` | `household`, month, winner, totals, `celebrated_by` (who has seen the confetti) |

*Avatar colors are derived from a member's joining order (see section 8.2).*

### 6.3 Integrity rules
- Assignees and completers must be active members of the task's household.
- `TASK.household_id` must match its template's household.
- Status fields must agree with their timestamps (for example, `done` implies `completed_at`).
- Status values and reasons are native enums or `CHECK` constraints.
- Database integrity and schema isolation per microservice are managed via **Flyway**.

---

## 7. Architecture


```

Flutter app ──► OpenShift Route / Ingress ──► Quarkus Microservices ──► Managed PostgreSQL
│                                                │
└── Keycloak (RHBK / OIDC) ◄─────────────────────┴── Gotify push server

```

| Area | Decision |
| :--- | :--- |
| **Client** | Flutter, mobile first, web later. Clean, reusable code across platforms |
| **Backend** | Java 21 / Quarkus **microservices architecture**: `households`, `tasks`, `scoring`, `lists`, `notifications`. REST Jackson / RESTEasy Reactive |
| **Database** | Managed PostgreSQL (EU). Microservice-isolated schemas managed via **Flyway** migrations |
| **Platform** | **Red Hat OpenShift Platform (OCP)** using OpenShift Routes, Deployments, ConfigMaps, Secrets, and Health Probes |
| **Auth** | **Keycloak** (OIDC / OAuth2) behind an `AuthVerifier` interface. Validated via `quarkus-oidc` |
| **Push** | Gotify (self-hosted) behind a `PushSender` interface, fed by transactional outbox tables |
| **Scheduling** | Quarkus Scheduler / Quartz loop on Postgres: claims due rows with `FOR UPDATE SKIP LOCKED`, one transaction per job |
| **Packaging** | Container images built via Quarkus container extensions / Jib, deployed via Helm / Kustomize on OpenShift |
| **API style** | REST with OpenAPI (SmallRye) and a generated Dart client |

### Architecture Decision Records (ADRs)
- **0001** — Token values that can carry text
- **0002** — Quarkus REST / RESTEasy Reactive for backend services
- **0003** — OpenShift Local (CRC) / Podman for local development
- **0004** — Flyway for schema migrations
- **0005** — Verifying Keycloak JWT bearer tokens via OpenID Connect
- **0006** — A generated Dart client outside `app/`, not committed
- **0007** — A parsed-document check against OpenAPI drift
- **0011** — Recurrence computation in Quarkus services
- **0013** — Push notification gateway behind a `PushSender` seam
- **0027** — Push notifications are delivered through Gotify

### Repository layout (Monorepo)

```

backend/
build.gradle.kts / pom.xml
services/
households-service/
tasks-service/
scoring-service/
lists-service/
notifications-service/
common-domain/
app/            Flutter app
deploy/         Helm / Kustomize manifests for OpenShift, Containerfiles, local scripts
documentation/  project-specification.md, tasks.md, decisions/ (ADRs), api/openapi.yaml
AGENTS.md

```

### Container & OpenShift principles
- Small multi-stage images, stateless, configured by environment variables and OpenShift ConfigMaps/Secrets.
- `/health/live` and `/health/ready` endpoints via SmallRye Health, with graceful shutdown on SIGTERM.
- Database migrations run as separate init containers or dedicated one-shot deployment jobs, never at API startup in production.
- Structured JSON logs (`quarkus-logging-json`) with OpenTelemetry tracing.

---

## 8. Design and UX

*(Look and feel details remain preserved from earlier design iterations).*

### 8.1 Principles
- **Calm:** Rounded shapes, soft green (`#0B7A70`), generous spacing.
- **Never alarming:** Overdue is soft coral, focusing on what is still possible ("still +4").
- **Celebrate, don't shame:** Podium, confetti, and effort bar highlight contributions.

### 8.2 Navigation & Screens
- **Navigation:** Four bottom tabs (All Chores, My Chores, Leaderboard, Lists; the design names the fourth "Lists") and a Household Switcher at the top.
- **Household screen, templates:** a "Chore templates" section lists the household's active templates as cards (emoji, title, points on time and if late). Admins see an "Add a template" button and open a template's edit form by tapping its card; the form has title (required), emoji, description, points and late points (whole numbers, 0 or more). Members see the list without these actions. Editing a template never changes past tasks (§3.1).
- **Quick-log flow:** "+ I just did…" floating button; picking a template logs it after 5 seconds unless the person taps Undo in that time (nothing is created, so there is nothing to revert). Leaving the screen within the 5 seconds sends the log.

---

## 9. Cross-cutting requirements

- **Languages:** French and English at launch, externalized ARB files.
- **Privacy / GDPR:** EU hosting for database instances. Account deletion triggers user removal/anonymization in Keycloak and across microservice schemas. A household's only admin cannot delete the account while the household has other members (hand over the admin role first); a household where the user is the only member is deleted with the account. Other systems are told until each confirmed (ADR 0028).
- **Swappability:** External dependencies remain behind Java interfaces (`AuthVerifier`, `PushSender`).
- **Quality:** Spec-driven development, unit/integration testing with JUnit 5 and Quarkus Testcontainers.

---

## 10. Implementation plan

| Phase | Content |
| :--- | :--- |
| **0. Foundations** | Monorepo structure, OpenShift environment setup, Quarkus microservice scaffolding, Flyway, Keycloak integration |
| **1. Households** | User registration, household creation, memberships, invitations, roles, away management |
| **2. Tasks** | Task templates, quick-logging, completions, dismissals, reassignment |
| **3. Scoring** | Append-only ledger, reversions, scoreboard (Week/Month/Year/All time), podium, effort bar |
| **4. Automation** | Recurrence execution, round-robin assignments, Quarkus scheduler, outbox notifications, reminders |
| **5. Lists** | Checklists, item tracking, bulk reset |
| **6. Polish & Launch** | FR/EN translations, monthly recap, confetti animation, store releases, monitoring |

