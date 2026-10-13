# 0014 — Service accounts for service-to-service calls

## Context

tasks-service needs members, away status and household settings from households-service, both while handling user requests and in background jobs (recurrence spawn, reminders) where no user token exists. Services must not read each other's databases.

## Decision

tasks-service authenticates to Keycloak with its own client (`betterhome-tasks-service`, client credentials, `quarkus-oidc-client`) and sends that token to read-only `/v1/internal/...` endpoints of households-service. Those endpoints require the `service` realm role (read from `realm_access/roles`); household admins and members are refused. The same token is used on request paths and in jobs, so behavior does not depend on who triggered the work. Tasks verifies the user's own token before asking whether that subject is a member. The client secret comes from `OIDC_SERVICE_CLIENT_SECRET`; the realm export only carries a local-development placeholder.

## Consequences

The service account can read any household's members, so only trusted services may hold the `service` role and tasks must only pass household IDs it has authorized. Forwarding the user's token was rejected: it does not work in background jobs and would need two code paths. If households-service is unreachable, tasks answers 503 rather than treating the household as empty. Other services (scoring, T-0010) reuse the same pattern with their own clients.
