#!/usr/bin/env bash
# Load a demo household with two members and sample templates, through the public APIs only
# (Keycloak users via kcadm, tokens via the password grant, then households-service and
# tasks-service REST). Idempotent: existing users, household, membership and templates are kept.
# Requires `make up`. Local development only: the demo password is a placeholder.
set -euo pipefail

# shellcheck source=deploy/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

HOUSEHOLDS_URL="${HOUSEHOLDS_URL:-http://localhost:${HOUSEHOLDS_PORT}}"
TASKS_URL="${TASKS_URL:-http://localhost:${TASKS_PORT}}"
DEMO_PASSWORD="${DEMO_PASSWORD:-demo}"
HOUSEHOLD_NAME="Demo Home"
TIMEZONE="Europe/Paris"

# api <token> <method> <url> [json body]: authenticated JSON call, fails on HTTP errors.
api() {
  local token="$1" method="$2" url="$3"
  if [[ $# -ge 4 ]]; then
    curl -fsS -X "$method" -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' -d "$4" "$url"
  else
    curl -fsS -X "$method" -H "Authorization: Bearer ${token}" "$url"
  fi
}

ensure_user alice "$DEMO_PASSWORD" alice@betterhome.local Alice
ensure_user bob "$DEMO_PASSWORD" bob@betterhome.local Bob

alice_token="$(get_token alice "$DEMO_PASSWORD")"
bob_token="$(get_token bob "$DEMO_PASSWORD")"

for who in alice bob; do
  token_var="${who}_token"
  api "${!token_var}" PUT "${HOUSEHOLDS_URL}/v1/me" \
    "{\"email\":\"${who}@betterhome.local\",\"givenName\":\"${who^}\",\"language\":\"en\",\"timezone\":\"${TIMEZONE}\"}" >/dev/null
done

household_id="$(api "$alice_token" GET "${HOUSEHOLDS_URL}/v1/households" \
  | jq -r --arg name "$HOUSEHOLD_NAME" 'map(select(.name == $name)) | first | .id // empty')"
if [[ -z "$household_id" ]]; then
  household_id="$(api "$alice_token" POST "${HOUSEHOLDS_URL}/v1/households" \
    "{\"name\":\"${HOUSEHOLD_NAME}\",\"timezone\":\"${TIMEZONE}\"}" | jq -r .id)"
  echo "seed: created household ${household_id}"
else
  echo "seed: household ${household_id} exists"
fi

bob_is_member="$(api "$bob_token" GET "${HOUSEHOLDS_URL}/v1/households" \
  | jq -r --arg id "$household_id" 'any(.[]; .id == $id)')"
if [[ "$bob_is_member" != "true" ]]; then
  invitation_token="$(api "$alice_token" POST "${HOUSEHOLDS_URL}/v1/households/${household_id}/invitations" \
    '{"email":"bob@betterhome.local","role":"member"}' | jq -r .token)"
  api "$bob_token" POST "${HOUSEHOLDS_URL}/v1/invitations/${invitation_token}/accept" >/dev/null
  echo "seed: bob joined the household"
else
  echo "seed: bob is already a member"
fi

existing_titles="$(api "$alice_token" GET "${TASKS_URL}/v1/households/${household_id}/templates" | jq -r '.[].title')"
add_template() {
  local title="$1" emoji="$2" points="$3" late_points="$4" offset_minutes="$5"
  if grep -qxF "$title" <<<"$existing_titles"; then
    echo "seed: template '${title}' exists"
    return
  fi
  api "$alice_token" POST "${TASKS_URL}/v1/households/${household_id}/templates" \
    "{\"title\":\"${title}\",\"emoji\":\"${emoji}\",\"points\":${points},\"latePoints\":${late_points},\"defaultDueOffsetMinutes\":${offset_minutes}}" >/dev/null
  echo "seed: created template '${title}'"
}
add_template "Do the dishes" "🍽️" 5 2 120
add_template "Take out the trash" "🗑️" 3 1 240
add_template "Vacuum the living room" "🧹" 10 5 1440

echo "seed: OK (log in as alice / bob, password '${DEMO_PASSWORD}', household ${household_id})"
