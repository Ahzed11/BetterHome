# 0028 — Account deletion: households-service orchestrates, retries until every target confirmed

## Context

Spec §9 and AGENTS §8 require that deleting an account removes the user in Keycloak and anonymizes their history in every service. The data lives in five databases and one identity provider, with no distributed transaction.

## Decision

`DELETE /v1/me` in households-service (202) does the local part in one transaction: the last-admin rule is checked, the user leaves every household, a household where they are the only member is deleted with them, queued notification events and invitations to their address are dropped or blanked, the profile is anonymized (row kept, subject kept so a surviving token cannot re-register) and a row in `account_deletion` records the remaining work. A sole admin of a household that has other members gets 409 and must hand over the role (or delete the household) first.

The remaining work is a list of targets (tasks, scoring, lists, notifications, identity). Each is called once at once, then by a scheduler every 15 s with the outbox backoff, without a retry limit (a deletion that never finishes leaves personal data behind; after 10 attempts the log line is an error). Each confirmed target is stored in `account_deletion_step` and not called again. The internal anonymize endpoints are idempotent. Rows are claimed with `FOR UPDATE SKIP LOCKED`. Services are called with households-service's own service token (ADR 0014); the identity provider is behind the `IdentityAdmin` interface (Keycloak Admin REST `DELETE /users/{id}`, 404 counts as done) with an in-memory fake in the tests. The service account holds `manage-users` of `realm-management`.

## Consequences

The caller sees success before the other systems finished; the data in them is removed eventually, not synchronously. A user is deleted from Keycloak, not just disabled. Telling the services needs the user's id, so the anonymized profile row stays in households-service (without personal data). Not verified against a real Keycloak (see T-0106).
