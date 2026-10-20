#!/usr/bin/env bash
# Run the real app against the real local stack, for trying it by hand in a browser.
# Starts the stack (unless RUN_APP_STACK=running), makes sure the demo users exist, then serves the
# web build on http://localhost:${RUN_APP_PORT} until Ctrl-C. The stack keeps running; `make down` stops it.
# Sign in with RUN_APP_USER / RUN_APP_PASSWORD (default alice / demo; bob / demo also exists, to invite).
# RUN_APP_SEED=1 also loads the demo household and templates (`make seed`).
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"
# shellcheck source=../deploy/lib.sh
source "$TOOLING_DIR/../deploy/lib.sh"

# The web port is part of the stack (CORS, Keycloak redirect URIs): RUN_APP_PORT overrides the slot's.
export WEB_PORT="${RUN_APP_PORT:-$WEB_PORT}"
RUN_APP_PORT="$WEB_PORT"
RUN_APP_STACK="${RUN_APP_STACK:-start}"
RUN_APP_USER="${RUN_APP_USER:-alice}"
RUN_APP_PASSWORD="${RUN_APP_PASSWORD:-demo}"
RUN_APP_SEED="${RUN_APP_SEED:-0}"
ROOT="$(cd "$TOOLING_DIR/.." && pwd)"

case "$RUN_APP_STACK" in
  start | running) ;;
  *) echo "run-app: unknown RUN_APP_STACK '$RUN_APP_STACK' (use start or running)" >&2; exit 2 ;;
esac

if [[ "$RUN_APP_STACK" == start ]]; then
  # The services answer the browser cross-origin: the web port must be in their CORS list.
  CORS_ORIGINS="http://localhost:${RUN_APP_PORT}" make -C "$ROOT" up
fi
ensure_user "$RUN_APP_USER" "$RUN_APP_PASSWORD" "${RUN_APP_USER}@betterhome.local" "$RUN_APP_USER"
ensure_user bob "$RUN_APP_PASSWORD" "bob@betterhome.local" bob
if [[ "$RUN_APP_SEED" == 1 ]]; then
  make -C "$ROOT" seed
fi

make -C "$ROOT" client
cd "$ROOT/app"
flutter pub get >/dev/null
echo
echo "run-app: open http://localhost:${RUN_APP_PORT} once it has compiled (about a minute)"
echo "run-app: sign in as ${RUN_APP_USER} / ${RUN_APP_PASSWORD}. Ctrl-C stops the app; 'make down' stops the stack."
exec flutter run -d web-server --release --no-pub --web-port="$RUN_APP_PORT" \
  --dart-define=API_BASE_URL=http://localhost:${HOUSEHOLDS_PORT} \
  --dart-define=TASKS_API_BASE_URL=http://localhost:${TASKS_PORT} \
  --dart-define=SCORING_API_BASE_URL=http://localhost:${SCORING_PORT} \
  --dart-define=LISTS_API_BASE_URL=http://localhost:${LISTS_PORT} \
  --dart-define=NOTIFICATIONS_API_BASE_URL=http://localhost:${NOTIFICATIONS_PORT} \
  --dart-define=KEYCLOAK_ISSUER=http://localhost:${KEYCLOAK_PORT}/realms/betterhome
