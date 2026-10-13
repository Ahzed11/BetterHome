# 0002 — Quarkus REST / RESTEasy Reactive for backend services

## Context

Backend microservices need a productive Java HTTP stack with good OpenShift fit, reactive-capable REST, and first-class OIDC.

## Decision

Use Quarkus 3 with `quarkus-rest` / `quarkus-rest-jackson` (RESTEasy Reactive) for all HTTP APIs.

## Consequences

APIs share one programming model (`@Path`, CDI, SmallRye OpenAPI). Blocking JDBC/Hibernate work stays on worker threads as Quarkus recommends.
