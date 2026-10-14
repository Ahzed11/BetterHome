#!/usr/bin/env bash
# Generates the Dart client from documentation/api/openapi.yaml into generated/betterhome_api (gitignored,
# ADR 0006). The generator jar is pinned in versions.env and downloaded on first use.
# Usage: tooling/generate-client.sh [spec] [output-dir]
set -euo pipefail
# shellcheck source=dev-env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"
ROOT="$(cd "$TOOLING_DIR/.." && pwd)"
SPEC="${1:-$ROOT/documentation/api/openapi.yaml}"
OUT="${2:-$ROOT/generated/betterhome_api}"
JAR="$DEV_TOOLS_DIR/openapi-generator/openapi-generator-cli-${OPENAPI_GENERATOR_VERSION}.jar"

if [[ ! -f "$JAR" ]]; then
  mkdir -p "$(dirname "$JAR")"
  PART="$(mktemp)"
  curl -fsSL -o "$PART" \
    "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${OPENAPI_GENERATOR_VERSION}/openapi-generator-cli-${OPENAPI_GENERATOR_VERSION}.jar"
  echo "${OPENAPI_GENERATOR_SHA256}  $PART" | sha256sum -c - >/dev/null || { rm -f "$PART"; echo "generator checksum mismatch" >&2; exit 1; }
  mv "$PART" "$JAR"
fi

rm -rf "$OUT"
java -jar "$JAR" generate --input-spec "$SPEC" --generator-name dart --output "$OUT" \
  --additional-properties=pubName=betterhome_api,pubVersion=1.0.0 >/dev/null
test -f "$OUT/lib/api.dart" || { echo "generation produced no client" >&2; exit 1; }
echo "Dart client generated in $OUT"
