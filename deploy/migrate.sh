#!/usr/bin/env bash
# Apply each service's Flyway migrations as a one-shot container on the Compose network.
# Services never migrate at startup (quarkus.flyway.migrate-at-start=false in prod); this is
# the local stand-in for the init container / Job used on OpenShift. Safe to rerun.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES=(households tasks scoring lists notifications)

FLYWAY_IMAGE="${FLYWAY_IMAGE:-docker.io/flyway/flyway:11-alpine}"
NETWORK="${COMPOSE_NETWORK:-betterhome_default}"
DB_USER="${DB_USER:-betterhome}"
DB_PASSWORD="${DB_PASSWORD:-betterhome}"

if ! podman network exists "$NETWORK"; then
  echo "Network ${NETWORK} not found: run 'make up' (or start postgres) first." >&2
  exit 1
fi

for svc in "${SERVICES[@]}"; do
  migrations="$ROOT/backend/services/${svc}-service/src/main/resources/db/migration"
  echo "Migrating betterhome_${svc}..."
  # :Z relabels the bind mount for rootless Podman/SELinux. Flyway retries the connection (once a
  # second) because `compose up -d` returns before Postgres accepts connections.
  podman run --rm --network "$NETWORK" \
    -v "${migrations}:/flyway/sql:ro,Z" \
    "$FLYWAY_IMAGE" \
    -url="jdbc:postgresql://postgres:5432/betterhome_${svc}" \
    -user="$DB_USER" -password="$DB_PASSWORD" \
    -locations=filesystem:/flyway/sql \
    -connectRetries=60 \
    migrate
done

echo "All databases migrated."
