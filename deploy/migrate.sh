#!/usr/bin/env bash
# Apply versioned SQL migrations to each service database after `make up`.
# Prefers host psql; falls back to `podman exec` into the Compose Postgres container.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICES=(households tasks scoring lists notifications)

export PGPASSWORD="${DB_PASSWORD:-betterhome}"
HOST="${DB_HOST:-localhost}"
PORT="${DB_PORT:-5432}"
USER="${DB_USER:-betterhome}"
CONTAINER="${POSTGRES_CONTAINER:-betterhome-postgres-1}"

run_psql() {
  local db="$1"
  shift
  if command -v psql >/dev/null 2>&1; then
    psql -h "$HOST" -p "$PORT" -U "$USER" -d "$db" "$@"
  elif command -v podman >/dev/null 2>&1 && podman container exists "$CONTAINER" 2>/dev/null; then
    # Map common flags for in-container psql (no -h/-p/-U needed inside the network namespace of the DB)
    local args=()
    local file=""
    local sql=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -v) args+=("$1" "$2"); shift 2 ;;
        -Atc) args+=("$1" "$2"); shift 2 ;;
        -c) args+=("$1" "$2"); shift 2 ;;
        -f)
          file="$2"
          shift 2
          ;;
        *)
          args+=("$1")
          shift
          ;;
      esac
    done
    if [[ -n "$file" ]]; then
      podman exec -i -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" \
        psql -U "$USER" -d "$db" "${args[@]}" -f - <"$file"
    else
      podman exec -i -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" \
        psql -U "$USER" -d "$db" "${args[@]}"
    fi
  else
    echo "Need host psql or a running Podman container named ${CONTAINER}" >&2
    exit 1
  fi
}

for svc in "${SERVICES[@]}"; do
  db="betterhome_${svc}"
  migration="$ROOT/backend/services/${svc}-service/src/main/resources/db/migration"
  echo "Migrating ${db}..."
  applied=$(run_psql "$db" -Atc \
    "SELECT to_regclass('public.flyway_schema_history') IS NOT NULL" 2>/dev/null || echo "f")
  if [[ "$applied" == "t" ]]; then
    echo "  already migrated (flyway_schema_history present); skipping SQL apply"
    continue
  fi
  run_psql "$db" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS flyway_schema_history (
    installed_rank INT NOT NULL,
    version VARCHAR(50),
    description VARCHAR(200) NOT NULL,
    type VARCHAR(20) NOT NULL,
    script VARCHAR(1000) NOT NULL,
    checksum INT,
    installed_by VARCHAR(100) NOT NULL,
    installed_on TIMESTAMP NOT NULL DEFAULT now(),
    execution_time INT NOT NULL,
    success BOOLEAN NOT NULL,
    PRIMARY KEY (installed_rank)
);
SQL
  rank=1
  for file in "$migration"/V*.sql; do
    [[ -f "$file" ]] || continue
    base="$(basename "$file")"
    version="$(echo "$base" | sed -E 's/^V([0-9]+)__.*/\1/')"
    description="$(echo "$base" | sed -E 's/^V[0-9]+__([^.]+)\.sql/\1/' | tr '_' ' ')"
    echo "  applying ${base}"
    run_psql "$db" -v ON_ERROR_STOP=1 -f "$file"
    run_psql "$db" -v ON_ERROR_STOP=1 -c \
      "INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success)
       VALUES (${rank}, '${version}', '${description}', 'SQL', '${base}', NULL, '${USER}', 0, TRUE);"
    rank=$((rank + 1))
  done
done

echo "All databases migrated."
