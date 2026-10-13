#!/usr/bin/env bash
# Smoke check for the local stack: all five services report ready, then one authenticated
# call proves real Keycloak tokens are accepted end to end (host -> Keycloak -> service).
set -euo pipefail

TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-180}"
SMOKE_USER="${SMOKE_USER:-smoke}"
SMOKE_PASSWORD="${SMOKE_PASSWORD:-smoke}"
ports=(8081 8082 8083 8084 8085)

deadline=$((SECONDS + TIMEOUT_SECONDS))
for port in "${ports[@]}"; do
  until curl -fsS "http://localhost:${port}/q/health/ready" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      echo "smoke: service on :${port} not ready after ${TIMEOUT_SECONDS}s" >&2
      exit 1
    fi
    sleep 2
  done
  echo "smoke: :${port} ready"
done

# shellcheck source=deploy/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
ensure_user "$SMOKE_USER" "$SMOKE_PASSWORD" "$SMOKE_USER@betterhome.local"
token="$(get_token "$SMOKE_USER" "$SMOKE_PASSWORD")"

# The same token must be accepted by every service (shared issuer, shared audience)
for port in "${ports[@]}"; do
  curl -fsS -H "Authorization: Bearer ${token}" "http://localhost:${port}/v1/meta" >/dev/null
  echo "smoke: :${port} accepted the Keycloak token"
done
curl -fsS -X PUT -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' \
  -d "{\"email\":\"${SMOKE_USER}@betterhome.local\"}" "http://localhost:8081/v1/me" >/dev/null
echo "smoke: OK"
