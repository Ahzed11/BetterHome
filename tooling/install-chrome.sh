#!/usr/bin/env bash
# Installs the pinned Chrome for Testing and its chromedriver under $DEV_TOOLS_DIR/chrome (idempotent).
# Used by install-dev-tools.sh and by the e2e job in CI; needs curl and unzip.
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
if [[ "$(cat "$DEV_TOOLS_DIR/chrome/.betterhome-version" 2>/dev/null || true)" != "$CHROME_VERSION" ]]; then
  rm -rf "$DEV_TOOLS_DIR/chrome"
  mkdir -p "$DEV_TOOLS_DIR/chrome"
  for artifact in chrome:"$CHROME_SHA256" chromedriver:"$CHROMEDRIVER_SHA256"; do
    name="${artifact%%:*}"
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 -o "$WORK/$name.zip" \
      "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/${name}-linux64.zip"
    echo "${artifact#*:}  $WORK/$name.zip" | sha256sum -c -
    unzip -q "$WORK/$name.zip" -d "$DEV_TOOLS_DIR/chrome"
  done
  echo "$CHROME_VERSION" > "$DEV_TOOLS_DIR/chrome/.betterhome-version"
fi
