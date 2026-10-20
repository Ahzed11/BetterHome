#!/usr/bin/env bash
# Fails when a service's Dockerfile.* EXPOSE does not match the quarkus.http.port in its application.properties
# (T-0046, #37). Every Dockerfile variant must expose the real port, never Quarkus' default 8080.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0
for dir in "$root"/backend/services/*/; do
  service="$(basename "$dir")"
  port="$(sed -n 's/^quarkus\.http\.port=\([0-9]*\)[[:space:]]*$/\1/p' "$dir/src/main/resources/application.properties")"
  if [ -z "$port" ]; then
    echo "$service: no quarkus.http.port in application.properties" >&2
    status=1
    continue
  fi
  for file in "$dir"/src/main/docker/Dockerfile.*; do
    exposed="$(sed -n 's/^EXPOSE[[:space:]]\{1,\}\([0-9]\{1,\}\)[[:space:]]*$/\1/p' "$file")"
    if [ "$exposed" != "$port" ]; then
      echo "$service: $(basename "$file") exposes '${exposed:-nothing}', the service listens on $port" >&2
      status=1
    fi
  done
done
if [ "$status" -eq 0 ]; then
  echo "image ports: EXPOSE matches quarkus.http.port in every Dockerfile"
fi
exit "$status"
