#!/usr/bin/env bash
# Proves the generated-client guard works (ADR 0006): generation fails when the document is broken, and the
# app stops compiling when the contract drifts from what it uses. A control run on the real contract shows
# that the failures come from the damage and not from the harness.
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"
ROOT="$(cd "$TOOLING_DIR/.." && pwd)"
SPEC="$ROOT/documentation/api/openapi.yaml"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

expect_failure() { # description, command...
  local what="$1"; shift
  if "$@" >"$WORK/out.log" 2>&1; then
    echo "GUARD FAILED: $what was accepted" >&2
    exit 1
  fi
  echo "ok: $what is rejected"
}

# analyze_app <spec>: generates a client from <spec> into a scratch copy of the app and analyzes the copy
analyze_app() {
  local spec="$1" copy="$WORK/copy-$RANDOM"
  mkdir -p "$copy"
  tar -C "$ROOT" --exclude=app/.dart_tool --exclude=app/build -cf - app | tar -C "$copy" -xf -
  bash "$TOOLING_DIR/generate-client.sh" "$spec" "$copy/generated/betterhome_api"
  (cd "$copy/app" && flutter pub get && flutter analyze)
}

echo "== Broken documents"
sed 's|#/components/schemas/UserResponse|#/components/schemas/NoSuchSchema|' "$SPEC" > "$WORK/dangling-ref.yaml"
expect_failure "a document with a dangling reference" \
  bash "$TOOLING_DIR/generate-client.sh" "$WORK/dangling-ref.yaml" "$WORK/out-ref"
printf 'not: [valid' > "$WORK/garbage.yaml"
expect_failure "an unparseable document" \
  bash "$TOOLING_DIR/generate-client.sh" "$WORK/garbage.yaml" "$WORK/out-garbage"

echo "== Control: the real contract compiles with the app"
analyze_app "$SPEC" >"$WORK/control.log" 2>&1 || { cat "$WORK/control.log"; echo "GUARD FAILED: control run" >&2; exit 1; }
echo "ok: app analyzes against a client generated from the real contract"

echo "== Drift: a field the app reads is renamed in the contract"
sed 's/^\( *\)createdBy:/\1creatorId:/' "$SPEC" > "$WORK/drifted.yaml"
cmp -s "$SPEC" "$WORK/drifted.yaml" && { echo "GUARD FAILED: the drift edit changed nothing" >&2; exit 1; }
expect_failure "an app built against a drifted client" analyze_app "$WORK/drifted.yaml"
echo "test-guard: OK"
