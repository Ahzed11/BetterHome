#!/usr/bin/env bash
# Fails when the self-hosted stack (deploy/nas, T-0108, ADR 0029) drifts from the services or leaks something it
# must not hold: the Caddyfile routes and ports must match every service, every image must be the project's own,
# nothing may be published to the host, the file must not need a .env, and no real host name may be committed.
# Needs no container tooling.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose="$root/deploy/nas/compose.yml"
caddy="$root/deploy/nas/Caddyfile"
status=0
fail() { echo "$1" >&2; status=1; }

for dir in "$root"/backend/services/*/; do
  service="$(basename "$dir")"
  name="${service%-service}"
  port="$(sed -n 's/^quarkus\.http\.port=\([0-9]*\)[[:space:]]*$/\1/p' "$dir/src/main/resources/application.properties")"
  [ -n "$port" ] || { fail "$service: no quarkus.http.port in application.properties"; continue; }
  grep -q "image: ghcr.io/ahzed11/betterhome-$service:" "$compose" || fail "$service: no image betterhome-$service in compose.yml"
  grep -q "^  betterhome-$name:" "$compose" || fail "$service: no service betterhome-$name in compose.yml"
  grep -q "reverse_proxy betterhome-$name:$port\$" "$caddy" || fail "$service: Caddyfile does not proxy betterhome-$name:$port"
  grep -q "handle /api/$name/\*" "$caddy" || fail "$service: Caddyfile has no /api/$name route"
  grep -q "/migrations/$name/" "$root/deploy/migrations/Dockerfile" || fail "$service: its SQL is not copied into the migrations image"
  grep -q "for service in .*\b$name\b" "$root/deploy/migrations/migrate-all.sh" || fail "$service: migrate-all.sh does not migrate it"
done
if grep -rqi "test.clock" "$root/deploy/nas" "$root/deploy/openshift"; then
  fail "deploy/nas and deploy/openshift must not mention the e2e test clock (/v1/test/clock moves time)"
fi
grep -q "image: ghcr.io/ahzed11/betterhome-migrations:" "$compose" || fail "compose.yml: no migrations image"
grep -q "image: ghcr.io/ahzed11/betterhome-keycloak:" "$compose" || fail "compose.yml: no keycloak image"
grep -q "reverse_proxy betterhome-keycloak:8180\$" "$caddy" || fail "Caddyfile: Keycloak is not proxied"
grep -q "KC_HTTP_RELATIVE_PATH=/auth" "$root/deploy/keycloak/Dockerfile" || fail "keycloak image: relative path is not /auth"
grep -q "reverse_proxy betterhome-gotify:80\$" "$caddy" || fail "Caddyfile: Gotify is not proxied"
grep -q '^redir /gotify /gotify/ permanent$' "$caddy" || fail "Caddyfile: /gotify without a slash must redirect (the web UI uses relative links)"
grep -q "^      GOTIFY_URL: http://betterhome-gotify:80\$" "$compose" || fail "compose.yml: notifications-service must push to http://betterhome-gotify:80 (ADR 0027)"
grep -q "^      - gotify-data:/app/data\$" "$compose" || fail "compose.yml: Gotify's data must be in a volume"

grep -q "image: docker.io/prodrigestivill/postgres-backup-local:" "$compose" || fail "compose.yml: no backup service"
for name in households tasks scoring lists notifications keycloak; do
  grep -q "^      POSTGRES_DB: .*betterhome_$name\b" "$compose" || fail "compose.yml: the backup service does not dump betterhome_$name"
done
grep -q "^      - gotify-data:/data:ro\$" "$compose" || fail "compose.yml: Gotify's data is not backed up (read-only mount)"
[ -x "$root/deploy/nas/update.sh" ] && [ -x "$root/deploy/nas/restore.sh" ] || fail "deploy/nas: update.sh and restore.sh must exist and be executable"

grep -Eq '^ +ports:' "$compose" && fail "compose.yml: a port is published to the host, only Caddy may reach the stack"
grep -Eq 'env_file|(^|[^$])\$\{' "$compose" && fail "compose.yml: it must not need a .env file or environment interpolation"
grep -Eq '^  edge:' "$compose" && grep -A2 '^  edge:' "$compose" | grep -q 'external: true' || fail "compose.yml: edge must be the external network"
grep -Eq '^  (postgres|migrate|init-databases):' "$compose" || fail "compose.yml: postgres, init-databases and migrate are missing"
# Postgres and the one-shot jobs stay off the shared network: they must not list edge.
for private in postgres init-databases migrate; do
  block="$(awk -v s="  $private:" '$0==s{f=1;next} f&&/^  [a-z]/{exit} f' "$compose")"
  grep -v '^ *#' <<<"$block" | grep -q 'edge' && fail "compose.yml: $private is on the shared edge network"
done
# Every service on edge must carry the betterhome- prefix (service names are DNS names on a shared network).
awk '/^  [a-z][a-z-]*:$/{name=$1} /^      - edge$/{print name}' "$compose" | while read -r name; do
  case "$name" in betterhome-*:) ;; *) echo "compose.yml: $name joins edge without the betterhome- prefix" >&2; exit 1 ;; esac
done || status=1

# No real tailnet name or secret: host names are placeholders, passwords are CHANGE_ME.
grep -Eoh '[A-Za-z0-9.-]+\.ts\.net' "$compose" "$caddy" "$root/deploy/nas/README.md" | grep -v '^nas\.example\.ts\.net$' | grep -q . && fail "deploy/nas: a .ts.net name other than nas.example.ts.net is committed"
grep -E '(PASSWORD|SECRET): *' "$compose" | grep -vq 'CHANGE_ME' && fail "compose.yml: a password or secret is not a CHANGE_ME placeholder"
# The realm baked into the Keycloak image reads its client secrets from the environment, never a literal value.
grep -E '"secret": ' "$root/deploy/keycloak/realm-betterhome.json" | grep -v '"\${[A-Z_]*:local-dev-only-change-me}"' | grep -q . && fail "realm-betterhome.json: a client secret is a literal, use \${NAME:default}"
for var in OIDC_SERVICE_CLIENT_SECRET API_CLIENT_SECRET; do
  grep -q "^      $var: CHANGE_ME" "$compose" || fail "compose.yml: Keycloak is not given $var"
done
[ "$status" -ne 0 ] || echo "nas stack: routes, ports, images and placeholders match every service"
exit "$status"
