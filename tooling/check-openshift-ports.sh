#!/usr/bin/env bash
# Fails when a service's OpenShift manifest drifts from the service itself (T-0004, #1): the containerPort and the
# Service port must equal quarkus.http.port, the probes must use the SmallRye Health paths under /q/health, and the
# image must be the service's own. Needs no cluster and no Kubernetes tooling.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0
fail() { echo "$1" >&2; status=1; }
for dir in "$root"/backend/services/*/; do
  service="$(basename "$dir")"
  port="$(sed -n 's/^quarkus\.http\.port=\([0-9]*\)[[:space:]]*$/\1/p' "$dir/src/main/resources/application.properties")"
  manifest="$root/deploy/openshift/base/$service.yaml"
  if [ -z "$port" ]; then fail "$service: no quarkus.http.port in application.properties"; continue; fi
  if [ ! -f "$manifest" ]; then fail "$service: no manifest at deploy/openshift/base/$service.yaml"; continue; fi
  [ "$(sed -n 's/^ *containerPort: *\([0-9]*\)$/\1/p' "$manifest")" = "$port" ] || fail "$service: containerPort is not $port"
  [ "$(sed -n 's/^ *port: *\([0-9][0-9]*\)$/\1/p' "$manifest")" = "$port" ] || fail "$service: Service port is not $port"
  [ "$(grep -c 'path: /q/health/live$' "$manifest")" = 2 ] || fail "$service: startup and liveness probes must use /q/health/live"
  [ "$(grep -c 'path: /q/health/ready$' "$manifest")" = 1 ] || fail "$service: readiness probe must use /q/health/ready"
  grep -q "image: ghcr.io/ahzed11/betterhome-$service:" "$manifest" || fail "$service: image is not betterhome-$service"
  grep -q "name: $service-migrate\$" "$manifest" || fail "$service: no migration Job"
  [ -d "$dir/src/main/resources/db/migration" ] || fail "$service: no db/migration directory"
done
[ "$status" -ne 0 ] || echo "openshift manifests: ports, health paths and images match every service"
exit "$status"
