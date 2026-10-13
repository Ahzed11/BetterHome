#!/usr/bin/env bash
# Runs the headless test AVD in the foreground (background it: `tooling/start-emulator.sh &`).
# KNOWN ISSUE (T-0045): on the current development VM the emulator process segfaults about 30 s
# after start, when the guest media service starts; these flags are the intended ones, not proven.
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"
rm -f "$HOME/.android/avd/${AVD_NAME}.avd/"*.lock
exec emulator -avd "$AVD_NAME" -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu swiftshader_indirect -accel on "$@"
