# 0003 — OpenShift Local (CRC) / Podman for local development

## Context

Developers need a local stack that mirrors OpenShift packaging without requiring a full cluster on day one.

## Decision

Phase 0 uses **Podman Compose** for Postgres and Keycloak. OpenShift Local (CRC) / `oc` manifests under `deploy/` are added as services harden toward production.

## Consequences

`make up` is fast and works offline-ish. CRC remains the path for Route/ConfigMap/Secret parity before launch.
