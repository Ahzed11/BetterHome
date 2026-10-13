#!/usr/bin/env bash
# Fails when a tool needed to build, test and run BetterHome is missing or not the pinned version.
set -uo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"

FAILURES=0
check() { # check "<label>" <command...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok       %s\n' "$label"
  else
    printf '  MISSING  %s\n' "$label"
    FAILURES=$((FAILURES + 1))
  fi
}
java_major() { java -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p'; }
flutter_version() { flutter --version --machine 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)["frameworkVersion"])'; }
is_pinned_java() { [[ "$(java_major)" == "$JAVA_MAJOR" ]]; }
is_pinned_flutter() { [[ "$(flutter_version)" == "$FLUTTER_VERSION" ]]; }
has_podman_socket() { [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock" ]]; }
has_avd() { avdmanager list avd -c | grep -qx "$AVD_NAME"; }
has_kvm() { [[ -r /dev/kvm && -w /dev/kvm ]]; }
IMAGE_DIR="$ANDROID_SDK_ROOT/system-images/android-${ANDROID_API}/${ANDROID_IMAGE_TAG}/${ANDROID_ABI}"

echo "Backend"
check "JDK ${JAVA_MAJOR} (jbang jdk install ${JAVA_MAJOR})" is_pinned_java
check "podman" podman --version
check "podman compose provider" podman compose version
check "podman API socket (systemctl --user enable --now podman.socket)" has_podman_socket
echo "App"
check "Flutter ${FLUTTER_VERSION}" is_pinned_flutter
check "dart" dart --version
echo "Android"
check "adb (platform-tools)" adb --version
check "emulator" emulator -version
check "platform android-${ANDROID_API}" test -d "$ANDROID_SDK_ROOT/platforms/android-${ANDROID_API}"
check "build-tools ${ANDROID_BUILD_TOOLS}" test -d "$ANDROID_SDK_ROOT/build-tools/${ANDROID_BUILD_TOOLS}"
check "system image ${ANDROID_IMAGE_TAG}/${ANDROID_ABI}" test -d "$IMAGE_DIR"
check "AVD ${AVD_NAME}" has_avd
check "/dev/kvm readable and writable (hardware acceleration)" has_kvm

if ((FAILURES > 0)); then
  echo "doctor: ${FAILURES} problem(s). Install the toolchain with: tooling/install-dev-tools.sh" >&2
  exit 1
fi
echo "doctor: all tools present"
