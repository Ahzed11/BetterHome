#!/usr/bin/env bash
# Apply Flyway migrations to each service database using Quarkus Flyway Maven plugin
# or the flyway CLI when available. For local use after `make up`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/backend"

export JAVA_HOME="${JAVA_HOME:-$(jbang jdk home 21 2>/dev/null || true)}"
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
  echo "JAVA_HOME must point to JDK 21" >&2
  exit 1
fi
export PATH="$JAVA_HOME/bin:$PATH"

SERVICES=(households tasks scoring lists notifications)
declare -A PORTS=(
  [households]=8081
  [tasks]=8082
  [scoring]=8083
  [lists]=8084
  [notifications]=8085
)

# Run each service once with migrate-at-start in a one-shot Quarkus process would be heavy.
# Instead use Flyway via quarkus:dev is wrong; use JDBC URL + quarkus.flyway in a short Maven goal.
# Practical Phase 0 approach: start each service briefly is too slow.
# Use Flyway Maven plugin if on classpath, else psql apply of V1 scripts.

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required for make migrate in Phase 0" >&2
  exit 1
fi

export PGPASSWORD="${DB_PASSWORD:-betterhome}"
HOST="${DB_HOST:-localhost}"
PORT="${DB_PORT:-5432}"
USER="${DB_USER:-betterhome}"

for svc in "${SERVICES[@]}"; do
  db="betterhome_${svc}"
  migration="$ROOT/backend/services/${svc}-service/src/main/resources/db/migration"
  echo "Migrating ${db}..."
  # Apply versioned SQL files in order if flyway_schema_history missing
  applied=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d "$db" -Atc \
    "SELECT to_regclass('public.flyway_schema_history') IS NOT NULL" 2>/dev/null || echo "f")
  if [[ "$applied" == "t" ]]; then
    echo "  already migrated (flyway_schema_history present); skipping SQL apply"
    echo "  (services apply Flyway on %dev start; production uses init jobs)"
    continue
  fi
  # Create flyway history and apply V* files for local bootstrap without starting Quarkus
  psql -h "$HOST" -p "$PORT" -U "$USER" -d "$db" -v ON_ERROR_STOP=1 <<'SQL'
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
    psql -h "$HOST" -p "$PORT" -U "$USER" -d "$db" -v ON_ERROR_STOP=1 -f "$file"
    psql -h "$HOST" -p "$PORT" -U "$USER" -d "$db" -v ON_ERROR_STOP=1 -c \
      "INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success)
       VALUES (${rank}, '${version}', '${description}', 'SQL', '${base}', NULL, '${USER}', 0, TRUE);"
    rank=$((rank + 1))
  done
done

echo "All databases migrated."
