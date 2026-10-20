#!/usr/bin/env bash
# Renders the OpenShift Local overlay offline and validates it (T-0004, #1). Needs `kustomize`, `oc` or `kubectl`
# on PATH; `kubeconform` is used when present (Routes have no schema there and are skipped). No cluster involved.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The migration ConfigMaps read backend/**/db/migration, outside the kustomization root.
flags=(--load-restrictor=LoadRestrictionsNone)
if command -v kustomize >/dev/null; then render=(kustomize build "${flags[@]}")
elif command -v oc >/dev/null; then render=(oc kustomize "${flags[@]}")
elif command -v kubectl >/dev/null; then render=(kubectl kustomize "${flags[@]}")
else echo "test-openshift: install kustomize, oc or kubectl" >&2; exit 1; fi

out="$(mktemp --suffix=.yaml)" # kubeconform only reads .yaml/.json files
trap 'rm -f "$out"' EXIT
"${render[@]}" "$root/deploy/openshift/crc" > "$out"
echo "rendered $(grep -c '^kind:' "$out") resources from deploy/openshift/crc"
if command -v kubeconform >/dev/null; then
  kubeconform -strict -summary -ignore-missing-schemas "$out"
else
  echo "kubeconform not installed: rendered only, schemas not checked" >&2
fi
