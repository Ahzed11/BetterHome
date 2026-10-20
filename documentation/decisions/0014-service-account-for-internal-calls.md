# 0014 — Service accounts for service-to-service calls

## Context

tasks-service needs members, away status and household settings from households-service, both while handling user requests and in background jobs (recurrence spawn, reminders) where no user token exists. Services must not read each other's databases.

## Decision

tasks-service authenticates to Keycloak with its own client (`betterhome-tasks-service`, client credentials, `quarkus-oidc-client`) and sends that token to read-only `/v1/internal/...` endpoints of households-service. Those endpoints require the `service` realm role (read from `realm_access/roles`); household admins and members are refused. The same token is used on request paths and in jobs, so behavior does not depend on who triggered the work. Tasks verifies the user's own token before asking whether that subject is a member. The client secret comes from `OIDC_SERVICE_CLIENT_SECRET`; the realm export only carries a local-development placeholder.

## Consequences

The service account can read any household's members, so only trusted services may hold the `service` role and tasks must only pass household IDs it has authorized. Forwarding the user's token was rejected: it does not work in background jobs and would need two code paths. If households-service is unreachable, tasks answers 503 rather than treating the household as empty. Other services (scoring, T-0010) reuse the same pattern with their own clients.

## Addendum (T-0010): scoring

Scoring has its own client (`betterhome-scoring-service`) and asks households-service for members the same way tasks does. In the other direction, tasks calls scoring's `POST /v1/households/{id}/points/award` and `/reverse` with its existing service token; both methods require the `service` role, so household admins and members are refused on them. The ledger is written only by tasks-service, which has already authorized the acting user, so scoring no longer checks household membership for these two calls. Because the caller is no longer the admin, the reverse request carries `adminUserId`, and scoring still verifies through households that this user is an active admin before recording the reversion. User-facing scoring endpoints (scoreboard, winners, adjust, celebrations) keep user tokens and membership checks.

Failure policy: any failed call to scoring (outage, rejected token, dropped connection) makes the tasks operation fail with 503. The ledger call is the last step inside the task's transaction, so a failed award rolls the completion back and a failed reversal leaves the task `done`. If scoring commits and tasks then fails to commit, points exist without a done task; closing that gap needs idempotent awards or an outbox (follow-up T-0040).

## Addendum (T-0026): outbox relays

households-service now also has a client (`betterhome-households-service`) and its service account holds the `service` role, to call notifications-service's event ingest from its outbox relay (ADR 0017); tasks-service uses its existing client for the same. The `service` role is what ingest requires, so no new role was added. Both relays call notifications-service only; households still sends the admin's token to tasks-service for the away dismissal.

## Addendum (T-0012): households writes to tasks

Households has its own client (`betterhome-households-service`) and, from a scheduler, calls tasks-service's `POST /v1/internal/households/{id}/tasks/dismiss-away/{userId}?dismissedBy=` when a future-dated away period begins. No user token exists in that job, so the endpoint requires the `service` role, the same role as the other internal endpoints; no new role is introduced because the three service accounts are equally trusted and a finer split would be a layer without a present need. The endpoint trusts the caller's `dismissedBy` (the admin recorded in `away_set_by`) and does not re-check membership, so only households-service may hold the `service` role for it and it must pass only IDs it owns. Users, including admins, are refused on it; admins keep the user-token endpoint used when they set the member away.

Failure policy: the job claims one due membership with `FOR UPDATE SKIP LOCKED`, calls tasks-service and sets `away_tasks_dismissed_at` in one transaction. Any failed call rolls back, leaves the period due and ends the run; the next run (every 30 seconds) retries. A call that succeeds followed by a failed commit dismisses again on retry, which is harmless because dismissing is idempotent.
