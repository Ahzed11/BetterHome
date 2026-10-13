#!/usr/bin/env bash
# Installs the pinned Flutter SDK, Android SDK, emulator image and test AVD (idempotent).
# System packages need sudo (Fedora/dnf); everything else lives under $HOME.
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
IMAGE="system-images;android-${ANDROID_API};${ANDROID_IMAGE_TAG};${ANDROID_ABI}"

echo "== System packages"
PACKAGES=(git unzip zip xz which curl mesa-libGL mesa-libEGL alsa-lib pulseaudio-libs nss
  libX11 libXext libXrender libXi libXtst libxcb)
MISSING=()
for package in "${PACKAGES[@]}"; do
  rpm -q "$package" >/dev/null 2>&1 || MISSING+=("$package")
done
if ((${#MISSING[@]})); then
  echo "Installing with sudo: ${MISSING[*]}"
  sudo dnf install -y "${MISSING[@]}"
fi

echo "== Flutter ${FLUTTER_VERSION}"
if [[ "$(cat "$DEV_TOOLS_DIR/flutter/.betterhome-version" 2>/dev/null || true)" != "$FLUTTER_VERSION" ]]; then
  mkdir -p "$DEV_TOOLS_DIR"
  curl -fsSL -o "$WORK/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  echo "${FLUTTER_SHA256}  $WORK/flutter.tar.xz" | sha256sum -c -
  rm -rf "$DEV_TOOLS_DIR/flutter"
  tar -xJf "$WORK/flutter.tar.xz" -C "$DEV_TOOLS_DIR"
  echo "$FLUTTER_VERSION" > "$DEV_TOOLS_DIR/flutter/.betterhome-version"
fi
flutter config --no-analytics >/dev/null
flutter --version

echo "== Android command-line tools ${ANDROID_CMDLINE_TOOLS_BUILD}"
if [[ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
  curl -fsSL -o "$WORK/cmdtools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"
  echo "${ANDROID_CMDLINE_TOOLS_SHA256}  $WORK/cmdtools.zip" | sha256sum -c -
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  unzip -q "$WORK/cmdtools.zip" -d "$WORK/unpacked"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mv "$WORK/unpacked/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
fi

echo "== Android SDK packages (accepts the Android SDK licenses)"
yes | sdkmanager --licenses >/dev/null || true
sdkmanager --install "platform-tools" "emulator" "platforms;android-${ANDROID_API}" \
  "build-tools;${ANDROID_BUILD_TOOLS}" "$IMAGE"

echo "== AVD ${AVD_NAME}"
if ! avdmanager list avd -c | grep -qx "$AVD_NAME"; then
  echo no | avdmanager create avd --name "$AVD_NAME" --package "$IMAGE" --device pixel_6
fi

flutter config --android-sdk "$ANDROID_SDK_ROOT" >/dev/null
echo "== Done. Run: make doctor"
