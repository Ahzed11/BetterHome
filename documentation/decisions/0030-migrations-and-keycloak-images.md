# 0030 — Two more images: Flyway migrations and Keycloak, so a server needs no checkout

## Context

The self-hosted stack (`deploy/nas`, T-0108, ADR 0029) runs on a NAS that has no checkout of the repository. The five service images do not contain what the rest of the stack needs. The Flyway SQL lives in each service's sources and is applied by a one-shot job that must not run at service startup (AGENTS §3); locally `deploy/migrate.sh` mounts it from the checkout and OpenShift generates ConfigMaps from it. The Keycloak realm is a file in `deploy/keycloak` that the local stack mounts into the stock image in `start-dev`. Keycloak's production mode also has build-time options (database, health, the `/auth` path prefix of ADR 0029) that cannot be set at run time.

## Decision

`tooling/build-images.sh`, which already builds and publishes the five service images (ADR 0026), builds two more with the same prefix and tags:

- **`betterhome-migrations`** (`deploy/migrations/Dockerfile`): the Flyway image with every service's `db/migration` directory copied in and a script (`migrate-all.sh`) that migrates the five databases in turn. It runs as a one-shot Compose service that the services wait for.
- **`betterhome-keycloak`** (`deploy/keycloak/Dockerfile`): Keycloak 26 built for PostgreSQL with health and `KC_HTTP_RELATIVE_PATH=/auth`, with the realm in `data/import`. It starts with `start --optimized --import-realm`; the host name, database and admin password are run-time settings.

The databases themselves are created by a one-shot `postgres` container in the Compose file (idempotent), so no SQL file has to be delivered either. `tooling/check-nas.sh` (`make test-nas`) keeps the stack and the services aligned.

## Consequences

- Every merge into `master` publishes seven images instead of five; the SQL and the realm of a given commit travel with its tag, so a stack on one tag cannot migrate with another's files.
- The realm inside the image still holds the development client secrets until T-0109; the image is public like the repository.
- The local stack, `deploy/migrate.sh` and the OpenShift Jobs are unchanged.
- `make test-images` builds two more images (a pull of the Flyway and Keycloak base images, and a Keycloak build step).
