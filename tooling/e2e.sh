#!/usr/bin/env bash
# End-to-end journeys: the real app against the real local stack.
# Pick where the app runs with E2E_TARGET (default web):
#   web      app served to headless Chrome for Testing through chromedriver
#   android  app on the headless Android emulator (see T-0045 for the VM crash); no browser sign-in journey yet
# Other knobs: E2E_STACK=running reuses a stack that is already up (`make up`),
# E2E_WEB_PORT is the port the web build is served on (must match CORS_ORIGINS in the stack).
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"
# shellcheck source=../deploy/lib.sh
source "$TOOLING_DIR/../deploy/lib.sh"

E2E_TARGET="${E2E_TARGET:-web}"
E2E_STACK="${E2E_STACK:-start}"
E2E_WEB_PORT="${E2E_WEB_PORT:-8090}"
E2E_USER="${E2E_USER:-alice}"
E2E_PASSWORD="${E2E_PASSWORD:-demo}"
ROOT="$(cd "$TOOLING_DIR/.." && pwd)"

case "$E2E_TARGET" in
  web | android) ;;
  *) echo "e2e: unknown E2E_TARGET '$E2E_TARGET' (use web or android)" >&2; exit 2 ;;
esac
case "$E2E_STACK" in
  start | running) ;;
  *) echo "e2e: unknown E2E_STACK '$E2E_STACK' (use start or running)" >&2; exit 2 ;;
esac

cd "$ROOT/app"
flutter pub get >/dev/null
trap 'kill "${driver_pid:-}" "${server_pid:-}" 2>/dev/null || true' EXIT

# Journey 1 needs the app served as a user would get it. Compiling it needs no stack, so it starts now
# and compiles while the stack boots.
if [[ "$E2E_TARGET" == web ]]; then
  flutter run -d web-server --release --no-pub --web-port="$E2E_WEB_PORT" \
    --dart-define=API_BASE_URL=http://localhost:8081 \
    --dart-define=TASKS_API_BASE_URL=http://localhost:8082 \
    --dart-define=SCORING_API_BASE_URL=http://localhost:8083 \
    --dart-define=LISTS_API_BASE_URL=http://localhost:8084 \
    --dart-define=NOTIFICATIONS_API_BASE_URL=http://localhost:8085 \
    --dart-define=KEYCLOAK_ISSUER=http://localhost:8180/realms/betterhome >"$(mktemp)" 2>&1 &
  server_pid=$!
fi

if [[ "$E2E_STACK" == start ]]; then
  # The push gateway of the journeys is a real Gotify server (ADR 0027), started with the stack.
  COMPOSE_PROFILES=gotify GOTIFY_URL=http://gotify:80 CORS_ORIGINS="http://localhost:${E2E_WEB_PORT}" make -C "$ROOT" up
fi
ensure_user "$E2E_USER" "$E2E_PASSWORD" "${E2E_USER}@betterhome.local" "$E2E_USER"
ensure_user bob "$E2E_PASSWORD" "bob@betterhome.local" bob
# The account deletion journey deletes this user, so it cannot be one the other journeys need.
ensure_user carol "$E2E_PASSWORD" "carol@betterhome.local" carol

# The push gateway: bob's journey registers an application of this Gotify server as his push target,
# and what the server recorded is checked once the journeys finish.
GOTIFY_LOCAL_URL="${GOTIFY_LOCAL_URL:-http://localhost:8070}"
GOTIFY_ADMIN="admin:admin"
for _ in $(seq 1 60); do
  curl -fsS "${GOTIFY_LOCAL_URL}/health" >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS "${GOTIFY_LOCAL_URL}/health" >/dev/null \
  || { echo "e2e: no Gotify at ${GOTIFY_LOCAL_URL} (a stack started with E2E_STACK=running needs COMPOSE_PROFILES=gotify GOTIFY_URL=http://gotify:80)" >&2; exit 1; }
gotify_app="$(curl -fsS -u "$GOTIFY_ADMIN" -X POST "${GOTIFY_LOCAL_URL}/application" -d "name=e2e-$(date +%s)")"
gotify_app_id="$(jq -r .id <<<"$gotify_app")"
gotify_app_token="$(jq -r .token <<<"$gotify_app")"

# On the Android emulator the host is 10.0.2.2; Chrome reaches it as localhost.
host=localhost
[[ "$E2E_TARGET" == android ]] && host=10.0.2.2
# Tokens last about five minutes and the builds before a journey take longer, so they are fetched
# right before the journey that uses them.
set_defines() {
  defines=(
    "--dart-define=E2E_HOUSEHOLDS_URL=http://${host}:8081"
    "--dart-define=E2E_TASKS_URL=http://${host}:8082"
    "--dart-define=E2E_SCORING_URL=http://${host}:8083"
    "--dart-define=E2E_LISTS_URL=http://${host}:8084"
    "--dart-define=E2E_NOTIFICATIONS_URL=http://${host}:8085"
    "--dart-define=E2E_GOTIFY_APP_TOKEN=${gotify_app_token}"
    "--dart-define=E2E_ACCESS_TOKEN=$(get_token "$E2E_USER" "$E2E_PASSWORD")"
    "--dart-define=E2E_ACCESS_TOKEN_BOB=$(get_token bob "$E2E_PASSWORD")"
    "--dart-define=E2E_ACCESS_TOKEN_CAROL=$(get_token carol "$E2E_PASSWORD")"
  )
}

# The households service removes the user from Keycloak in the background after the account was
# deleted (ADR 0028), so the login is checked to be gone once the journeys finish.
assert_keycloak_user_gone() {
  local username="$1"
  for _ in $(seq 1 60); do
    kcadm_login
    if [[ -z "$(kcadm get users -r "$KEYCLOAK_REALM" -q "username=${username}" -q exact=true --fields id --format csv --noquotes)" ]]; then
      echo "e2e: Keycloak user ${username} is gone"
      return 0
    fi
    sleep 2
  done
  echo "e2e: Keycloak user ${username} still exists two minutes after the account was deleted" >&2
  return 1
}

# The notifications journey marks bob away, which must have reached his Gotify application: the
# English text, the type and only the minimal payload (ADR 0017, ADR 0027).
assert_gotify_received_away() {
  local messages
  messages="$(curl -fsS -u "$GOTIFY_ADMIN" "${GOTIFY_LOCAL_URL}/application/${gotify_app_id}/message")"
  if ! jq -e '[.messages[] | select(.title == "Marked away"
      and .extras["betterhome::push"].type == "marked_away"
      and (.extras["betterhome::push"] | keys - ["type"] | length == 0))] | length >= 1' \
    <<<"$messages" >/dev/null; then
    echo "e2e: Gotify did not receive the 'Marked away' push with the expected payload; it holds:" >&2
    jq -c '.messages[] | {title, message, extras}' <<<"$messages" >&2
    return 1
  fi
  echo "e2e: Gotify received the 'Marked away' push"
}

if [[ "$E2E_TARGET" == web ]]; then
  chromedriver --port=4444 >/dev/null 2>&1 &
  driver_pid=$!

  # Journey 1, real sign-in: a browser signs in through Keycloak's own login page (integration_test
  # cannot reach another origin) against the app served above.
  # While the app compiles, the dev server answers every path with index.html (HTTP 200), so only a
  # JavaScript answer means the app is ready.
  app_is_served() {
    [[ "$(curl -s -o /dev/null -w '%{content_type}' "http://localhost:${E2E_WEB_PORT}/main.dart.js")" == *javascript* ]]
  }
  for _ in $(seq 1 150); do
    app_is_served && break
    sleep 2
  done
  app_is_served || { echo "e2e: the app was not served" >&2; exit 1; }
  dart run test_driver/web_sign_in.dart "http://localhost:${E2E_WEB_PORT}" "$E2E_USER" "$E2E_PASSWORD"
  kill "$server_pid"; wait "$server_pid" 2>/dev/null || true
  server_pid=

  # Journey 2, the household and chores journeys with tokens fetched now (the test cannot sign in).
  set_defines
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/household_journey_test.dart \
    -d web-server --browser-name=chrome --chrome-binary="$CHROME_EXECUTABLE" --headless --web-port="$E2E_WEB_PORT" "${defines[@]}"
else
  set_defines
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/household_journey_test.dart \
    -d emulator-5554 "${defines[@]}"
fi

assert_gotify_received_away
assert_keycloak_user_gone carol
