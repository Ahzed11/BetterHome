# 0025 — The service images use the Red Hat hardened OpenJDK image

## Context

The five service images were built `FROM registry.access.redhat.com/ubi9/openjdk-21-runtime`, a general UBI image with a shell, a package manager and a launcher script. Red Hat publishes a catalog of hardened, minimal images at `registry.access.redhat.com/hi/`, pullable without authentication (checked on 2026-10-18 with `skopeo`). `hi/openjdk` has `21-runtime`, `21.0-runtime` and patch tags such as `21.0.12-runtime`; it runs as user 65532, has no entrypoint and sets `JAVA_HOME`.

## Decision

Every `Dockerfile.jvm` starts `FROM registry.access.redhat.com/hi/openjdk:21.0-runtime` (the minor line moves with security patches, the major version stays fixed), copies the Quarkus fast-jar into `/deployments` owned by 65532, runs as 65532 and starts `java -jar quarkus-run.jar` itself, since the UBI launcher script does not exist in this image. The `legacy-jar`, `native` and `native-micro` Dockerfiles that Quarkus generated are not used by Compose, CI or any task and are left as they are.

## Consequences

Smaller attack surface (no shell, no package manager, non-root). Memory settings the UBI launcher derived from the container limit are replaced by the JVM's own container support (`-XX:MaxRAMPercentage` defaults apply). Debugging inside a container needs an ephemeral debug container, not `exec sh`. The Compose healthchecks of Postgres and Keycloak are unaffected; the services have none. Not changed, and why: Keycloak and Flyway have no hardened equivalent in the catalog; a hardened PostgreSQL exists (`hi/postgresql:17`) but local data and init-script conventions differ from `postgres:16-alpine`, so it is a separate change (T-0099).
