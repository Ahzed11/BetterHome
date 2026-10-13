# 0005 — Verifying Keycloak JWT bearer tokens via OpenID Connect

## Context

Identity is Keycloak. Services must validate JWTs and map Keycloak `sub` to our `USER.auth_subject`.

## Decision

Use `quarkus-oidc` in service mode. The `AuthVerifier` seam in `common-domain` exposes the current subject. Domain tables use our own `USER.id`.

## Consequences

Keycloak can be replaced behind `AuthVerifier`. Tests use `@TestSecurity` with OIDC disabled in the test profile.
