#!/usr/bin/env bash
# Keeps the Podman API service running while idle (idempotent). `podman system service` exits after 5
# idle seconds by default; Testcontainers then fails with "Broken pipe" on the next container start,
# for example when Quarkus restarts between test classes (T-0120).
set -euo pipefail

DROPIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/podman.service.d"
DROPIN="$DROPIN_DIR/no-idle-timeout.conf"
WANTED=$'[Service]\nExecStart=\nExecStart=/usr/bin/podman $LOGGING system service --time=0\n'

if [[ "$(cat "$DROPIN" 2>/dev/null || true)" == "${WANTED%$'\n'}" ]]; then
  echo "Podman API idle timeout already disabled"
  exit 0
fi
mkdir -p "$DROPIN_DIR"
printf '%s' "$WANTED" > "$DROPIN"
systemctl --user daemon-reload
systemctl --user restart podman.socket
echo "Podman API idle timeout disabled ($DROPIN)"
