#!/usr/bin/env bash
# Builds the Android APK for trying the app on a phone (T-0111): a release-mode build signed with the debug key,
# so it installs by hand (adb or a download). It carries no server address: the app asks for it (T-0115), or
# runs in demo mode until then. Release signing for publishing is T-0116.
#
# Optional, for a personal build only (never publish it): NAS_HOST=nas.example.ts.net bakes in the server of
# ADR 0029 (Keycloak under /auth, each service under /api/<name>) with --dart-define, until the app can be pointed
# at a server from its own screen.
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"

ROOT="$(cd "$TOOLING_DIR/.." && pwd)"
APK="$ROOT/app/build/app/outputs/flutter-apk/app-release.apk"

defines=()
if [[ -n "${NAS_HOST:-}" ]]; then
  base="https://${NAS_HOST}"
  defines=(
    "--dart-define=API_BASE_URL=${base}/api/households"
    "--dart-define=TASKS_API_BASE_URL=${base}/api/tasks"
    "--dart-define=SCORING_API_BASE_URL=${base}/api/scoring"
    "--dart-define=LISTS_API_BASE_URL=${base}/api/lists"
    "--dart-define=NOTIFICATIONS_API_BASE_URL=${base}/api/notifications"
    "--dart-define=KEYCLOAK_ISSUER=${base}/auth/realms/betterhome"
  )
fi

cd "$ROOT/app"
flutter pub get >/dev/null
flutter build apk --release "${defines[@]}"

# What the phone needs, checked on the file that was built.
build_tools="$(ls -d "$ANDROID_SDK_ROOT"/build-tools/* | sort -V | tail -n 1)"
permissions="$("$build_tools/aapt" dump permissions "$APK")"
grep -q 'android.permission.INTERNET' <<<"$permissions" || { echo "apk: the INTERNET permission is missing, the app would have no network" >&2; exit 1; }
badging="$("$build_tools/aapt" dump badging "$APK")"
grep -q "package: name='com.betterhome.betterhome'" <<<"$badging" || { echo "apk: unexpected application id" >&2; exit 1; }
if [[ -z "${NAS_HOST:-}" ]] && unzip -p "$APK" 'lib/*/libapp.so' | strings | grep -Eq '\.ts\.net'; then
  echo "apk: a .ts.net name is baked into a build that should carry none" >&2
  exit 1
fi

echo "apk: $APK"
sha256sum "$APK"
"$build_tools/apksigner" verify --print-certs "$APK" | sed -n '1,3p'
if [[ -n "${NAS_HOST:-}" ]]; then
  echo "apk: personal build for ${NAS_HOST}: do not publish it"
else
  echo "apk: no server address inside"
fi
