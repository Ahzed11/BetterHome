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

if [[ "$E2E_STACK" == start ]]; then
  CORS_ORIGINS="http://localhost:${E2E_WEB_PORT}" make -C "$ROOT" up
fi
ensure_user "$E2E_USER" "$E2E_PASSWORD" "${E2E_USER}@betterhome.local" "$E2E_USER"
token="$(get_token "$E2E_USER" "$E2E_PASSWORD")"

# On the Android emulator the host is 10.0.2.2; Chrome reaches it as localhost.
host=localhost
[[ "$E2E_TARGET" == android ]] && host=10.0.2.2
defines=(
  "--dart-define=E2E_HOUSEHOLDS_URL=http://${host}:8081"
  "--dart-define=E2E_TASKS_URL=http://${host}:8082"
  "--dart-define=E2E_SCORING_URL=http://${host}:8083"
  "--dart-define=E2E_ACCESS_TOKEN=${token}"
)

cd "$ROOT/app"
flutter pub get >/dev/null
if [[ "$E2E_TARGET" == web ]]; then
  chromedriver --port=4444 >/dev/null 2>&1 &
  driver_pid=$!
  trap 'kill "$driver_pid" "${server_pid:-}" 2>/dev/null || true' EXIT

  # Journey 1, real sign-in: the app is served as a user would get it and a browser signs in through
  # Keycloak's own login page (integration_test cannot reach another origin).
  flutter run -d web-server --release --no-pub --web-port="$E2E_WEB_PORT" \
    --dart-define=API_BASE_URL=http://localhost:8081 \
    --dart-define=TASKS_API_BASE_URL=http://localhost:8082 \
    --dart-define=SCORING_API_BASE_URL=http://localhost:8083 \
    --dart-define=KEYCLOAK_ISSUER=http://localhost:8180/realms/betterhome >"$(mktemp)" 2>&1 &
  server_pid=$!
  for _ in $(seq 1 150); do
    curl -sf "http://localhost:${E2E_WEB_PORT}/main.dart.js" -o /dev/null && break
    sleep 2
  done
  curl -sf "http://localhost:${E2E_WEB_PORT}/main.dart.js" -o /dev/null || { echo "e2e: the app was not served" >&2; exit 1; }
  dart run test_driver/web_sign_in.dart "http://localhost:${E2E_WEB_PORT}" "$E2E_USER" "$E2E_PASSWORD"
  kill "$server_pid"; wait "$server_pid" 2>/dev/null || true
  server_pid=

  # Journey 2, repository calls with the token fetched above (the app cannot sign in from the test).
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/household_journey_test.dart \
    -d web-server --browser-name=chrome --chrome-binary="$CHROME_EXECUTABLE" --headless --web-port="$E2E_WEB_PORT" "${defines[@]}"
else
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/household_journey_test.dart \
    -d emulator-5554 "${defines[@]}"
fi
