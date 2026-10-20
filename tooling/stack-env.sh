#!/usr/bin/env bash
# Identity of one local stack (sourced, not executed): the Compose project name, every host port it
# publishes, and the directory for its generated files. Two stacks with different slots can run on
# one host without sharing a container, network, volume or port (ADR 0026).
#
# The slot is E2E_SLOT (0-9). Without it, a self-hosted runner named `<name>-<n>` takes slot n-1 and
# everything else takes slot 0, which keeps the historical names and ports (project `betterhome`,
# services :8081-:8085, Keycloak :8180, web app :8090). Slot n adds n * 1000 to each port.
# Any single variable below can still be overridden from the environment.

STACK_SLOT="${E2E_SLOT:-}"
if [[ -z "$STACK_SLOT" && "${RUNNER_NAME:-}" =~ -([0-9]+)$ ]]; then
  STACK_SLOT=$((BASH_REMATCH[1] - 1))
fi
STACK_SLOT="${STACK_SLOT:-0}"
if ! [[ "$STACK_SLOT" =~ ^[0-9]$ ]]; then
  echo "stack-env: E2E_SLOT must be a single digit (0-9), got '${STACK_SLOT}'" >&2
  return 2 2>/dev/null || exit 2
fi
_offset=$((STACK_SLOT * 1000))

if ((STACK_SLOT == 0)); then
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-betterhome}"
else
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-betterhome-s${STACK_SLOT}}"
fi
POSTGRES_PORT="${POSTGRES_PORT:-$((5432 + _offset))}"
KEYCLOAK_PORT="${KEYCLOAK_PORT:-$((8180 + _offset))}"
HOUSEHOLDS_PORT="${HOUSEHOLDS_PORT:-$((8081 + _offset))}"
TASKS_PORT="${TASKS_PORT:-$((8082 + _offset))}"
SCORING_PORT="${SCORING_PORT:-$((8083 + _offset))}"
LISTS_PORT="${LISTS_PORT:-$((8084 + _offset))}"
NOTIFICATIONS_PORT="${NOTIFICATIONS_PORT:-$((8085 + _offset))}"
WEB_PORT="${WEB_PORT:-$((8090 + _offset))}"
CHROMEDRIVER_PORT="${CHROMEDRIVER_PORT:-$((4444 + _offset))}"
unset _offset
# The services allow the web app's origin through CORS (browsers call them cross-origin).
CORS_ORIGINS="${CORS_ORIGINS:-http://localhost:${WEB_PORT}}"

# Generated per-stack files (the Keycloak realm with this stack's web origin). Gitignored.
STACK_DIR="${STACK_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/deploy/.stack/${COMPOSE_PROJECT_NAME}}"

REALM_FILE="${REALM_FILE:-$STACK_DIR/realm-betterhome.json}"

STACK_VARS="REALM_FILE CORS_ORIGINS COMPOSE_PROJECT_NAME POSTGRES_PORT KEYCLOAK_PORT HOUSEHOLDS_PORT TASKS_PORT SCORING_PORT LISTS_PORT NOTIFICATIONS_PORT WEB_PORT CHROMEDRIVER_PORT STACK_DIR"
# shellcheck disable=SC2163 # STACK_VARS holds variable names to export
for _var in $STACK_VARS; do export "$_var"; done
unset _var
