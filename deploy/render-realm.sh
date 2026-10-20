#!/usr/bin/env bash
# Write the Keycloak realm for this stack into $STACK_DIR: the checked-in realm file with the web
# app's origin (redirect URIs, web origins, post-logout URIs) moved from the default :8090 to this
# stack's WEB_PORT, so two stacks do not need the same browser port. Run by `make up`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tooling/stack-env.sh
source "$ROOT/tooling/stack-env.sh"

mkdir -p "$STACK_DIR"
sed "s#http://localhost:8090#http://localhost:${WEB_PORT}#g" \
  "$ROOT/deploy/keycloak/realm-betterhome.json" > "$STACK_DIR/realm-betterhome.json"
