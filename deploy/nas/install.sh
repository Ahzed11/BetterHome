#!/usr/bin/env bash
# One-step install of the BetterHome stack on the server (T-0121): fills every CHANGE_ME of compose.yml with the
# host name you give and freshly generated secrets, creates the shared `edge` network if it is missing, and starts the stack.
# Usage, from the folder of compose.yml: ./install.sh <tailnet-host> <backup-dir> [--no-start]
#   for example ./install.sh nas.example.ts.net /volume1/backups/betterhome
# It edits compose.yml in place and refuses to run twice (nothing left to fill in). The real values exist only there.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
usage() { echo "usage: $0 <tailnet-host> <backup-dir> [--no-start]" >&2; exit 2; }

start=1
args=()
for arg in "$@"; do
  case "$arg" in
    --no-start) start=0 ;;
    -*) usage ;;
    *) args+=("$arg") ;;
  esac
done
[[ ${#args[@]} -eq 2 ]] || usage
host="${args[0]}" backup="${args[1]}"

[[ "$host" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?\.[a-z0-9-]+$ ]] \
  || { echo "install: '$host' is not a host name like nas.example.ts.net" >&2; exit 1; }
[[ "$host" != "nas.example.ts.net" ]] || { echo "install: use the real name of your NAS on the tailnet" >&2; exit 1; }
[[ "$backup" == /* && "$backup" =~ ^[A-Za-z0-9/_.-]+$ ]] \
  || { echo "install: '$backup' must be an absolute path (letters, digits and / _ . - only)" >&2; exit 1; }
grep -v '^ *#' compose.yml | grep -q CHANGE_ME || { echo "install: compose.yml has no CHANGE_ME left, it is already filled in" >&2; exit 1; }

docker compose version >/dev/null 2>&1 || { echo "install: Docker Compose v2 is required (docker compose)" >&2; exit 1; }

secret() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
postgres_password="$(secret)"
keycloak_admin_password="$(secret)"
gotify_admin_password="$(secret)"
service_client_secret="$(secret)"
api_client_secret="$(secret)"

mkdir -p "$backup"
chmod 777 "$backup" 2>/dev/null || echo "install: could not chmod 777 $backup; the backup service needs it writable (chown 999:999 works too)" >&2

cp compose.yml compose.yml.template
sed -i \
  -e "s#CHANGE_ME_NAS_HOST#${host}#g" \
  -e "s#CHANGE_ME_POSTGRES_PASSWORD#${postgres_password}#g" \
  -e "s#CHANGE_ME_KEYCLOAK_ADMIN_PASSWORD#${keycloak_admin_password}#g" \
  -e "s#CHANGE_ME_GOTIFY_ADMIN_PASSWORD#${gotify_admin_password}#g" \
  -e "s#CHANGE_ME_SERVICE_CLIENT_SECRET#${service_client_secret}#g" \
  -e "s#CHANGE_ME_API_CLIENT_SECRET#${api_client_secret}#g" \
  -e "s#CHANGE_ME_BACKUP_DIR#${backup}#g" \
  compose.yml
chmod 600 compose.yml
if grep -v '^ *#' compose.yml | grep -q CHANGE_ME; then
  cp compose.yml.template compose.yml
  echo "install: a CHANGE_ME is left in compose.yml that this script does not know; compose.yml was put back" >&2
  exit 1
fi
rm compose.yml.template

docker network inspect edge >/dev/null 2>&1 || docker network create edge >/dev/null

if [[ "$start" -eq 1 ]]; then
  docker compose -f compose.yml up -d
  docker compose -f compose.yml ps
fi

here="$(pwd)"
cat <<EOF

install: done. Your passwords are in $here/compose.yml (readable by you only). Keep them with your other secrets.
  Keycloak admin   https://$host/auth        user admin, password $keycloak_admin_password
  Gotify admin     https://$host/gotify/     user admin, password $gotify_admin_password

Last step by hand: let your Caddy serve it. In the site block of $host in your Caddyfile, before any catch-all, add
    import $here/Caddyfile
and reload Caddy. Then check it from a machine on the tailnet:
    NAS_URL=https://$host API_CLIENT_SECRET=$api_client_secret SMOKE_USER=<user> SMOKE_PASSWORD=<password> make nas-smoke
(first create the user by signing up in the app, see README "First user").
EOF
