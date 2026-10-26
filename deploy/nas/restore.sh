#!/usr/bin/env bash
# Restores one database from a dump made by the backup service (T-0113). It replaces the database entirely.
# Usage, from the folder of compose.yml: ./restore.sh <database> <dump.sql.gz>
#   for example ./restore.sh betterhome_tasks /volume1/backups/betterhome/last/betterhome_tasks-latest.sql.gz
# Stop the services of that database first (docker compose stop betterhome-tasks): Postgres refuses to drop a
# database that is in use, and the script then changes nothing.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
[[ $# -eq 2 ]] || { echo "usage: $0 <database> <dump.sql.gz>" >&2; exit 2; }
database="$1" dump="$2"
[[ "$database" =~ ^betterhome_(households|tasks|scoring|lists|notifications|keycloak)$ ]] \
  || { echo "restore: '$database' is not a BetterHome database" >&2; exit 1; }
[[ -f "$dump" ]] || { echo "restore: $dump not found" >&2; exit 1; }
gzip -t "$dump" || { echo "restore: $dump is not a valid gzip file" >&2; exit 1; }

compose=(docker compose -f compose.yml)
psql=("${compose[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -U betterhome)

"${psql[@]}" -d postgres -c "DROP DATABASE IF EXISTS $database"
"${psql[@]}" -d postgres -c "CREATE DATABASE $database OWNER betterhome"
gunzip -c "$dump" | "${psql[@]}" -d "$database" >/dev/null
echo "restore: $database restored from $dump; start the services again with: docker compose -f compose.yml up -d"
