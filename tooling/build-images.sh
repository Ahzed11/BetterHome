#!/usr/bin/env bash
# Builds the five service images from the jars in backend/services/*/target (run `./mvnw package` first).
# Usage: tooling/build-images.sh <image-prefix> <tag>...   e.g. ghcr.io/owner/betterhome <sha> latest
# With PUSH=1 every tag is pushed after the build (log in to the registry first); without it, images stay local.
set -euo pipefail

prefix="${1:?image prefix, e.g. ghcr.io/owner/betterhome}"
shift
[ "$#" -gt 0 ] || { echo "at least one tag is required" >&2; exit 2; }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for dir in "$root"/backend/services/*/; do
  service="$(basename "$dir")"
  [ -f "$dir/target/quarkus-app/quarkus-run.jar" ] || { echo "no jar for $service: run ./mvnw package first" >&2; exit 1; }
  tags=()
  for tag in "$@"; do tags+=(-t "$prefix-$service:$tag"); done
  podman build -f "$dir/src/main/docker/Dockerfile.jvm" "${tags[@]}" "$dir"
  if [ "${PUSH:-0}" = 1 ]; then
    for tag in "$@"; do podman push "$prefix-$service:$tag"; done
  fi
done
