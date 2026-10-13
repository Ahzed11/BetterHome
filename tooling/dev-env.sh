#!/usr/bin/env bash
# Source this file to put the pinned toolchain on PATH:  source tooling/dev-env.sh
TOOLING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
# shellcheck source=versions.env
. "$TOOLING_DIR/versions.env"
set +a
export DEV_TOOLS_DIR="${DEV_TOOLS_DIR:-$HOME/dev-tools}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
PATH="$HOME/.jbang/bin:$DEV_TOOLS_DIR/flutter/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
if command -v jbang >/dev/null 2>&1; then
  JAVA_HOME="$(jbang jdk home "$JAVA_MAJOR" 2>/dev/null || true)"
  if [[ -n "$JAVA_HOME" ]]; then
    export JAVA_HOME
    PATH="$JAVA_HOME/bin:$PATH"
  fi
fi
export PATH
