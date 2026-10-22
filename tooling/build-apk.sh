#!/usr/bin/env bash
# Builds the Android APK for trying the app on a phone (T-0111): a release-mode build signed with the debug key,
# so it installs by hand (adb or a download). It carries no server address: the app asks for it on first launch
# (T-0115), which is also why the same file can be published. Release signing for publishing is T-0116.
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"

ROOT="$(cd "$TOOLING_DIR/.." && pwd)"
APK="$ROOT/app/build/app/outputs/flutter-apk/app-release.apk"

cd "$ROOT/app"
flutter pub get >/dev/null
flutter build apk --release

# What the phone needs, checked on the file that was built.
build_tools="$(ls -d "$ANDROID_SDK_ROOT"/build-tools/* | sort -V | tail -n 1)"
permissions="$("$build_tools/aapt" dump permissions "$APK")"
grep -q 'android.permission.INTERNET' <<<"$permissions" || { echo "apk: the INTERNET permission is missing, the app would have no network" >&2; exit 1; }
badging="$("$build_tools/aapt" dump badging "$APK")"
grep -q "package: name='com.betterhome.betterhome'" <<<"$badging" || { echo "apk: unexpected application id" >&2; exit 1; }
# No host name may be inside: the server is entered in the app, and the file may be published.
if unzip -p "$APK" 'lib/*/libapp.so' | strings | grep -Eq '\.ts\.net'; then
  echo "apk: a .ts.net name is baked into the build" >&2
  exit 1
fi

echo "apk: $APK"
sha256sum "$APK"
"$build_tools/apksigner" verify --print-certs "$APK" | sed -n '1,3p'
echo "apk: no server address inside, the app asks for it"
