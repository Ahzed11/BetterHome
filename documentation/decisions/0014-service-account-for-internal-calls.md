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
