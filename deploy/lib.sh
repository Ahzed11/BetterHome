#!/usr/bin/env bash
# Helpers shared by seed.sh and smoke.sh (sourced, not executed).
# Local development only: the Keycloak admin credentials and the betterhome-api client
# secret are the placeholders already used by podman-compose.yml and realm-betterhome.json.

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8180}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-betterhome}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
API_CLIENT_ID="${API_CLIENT_ID:-betterhome-api}"
API_CLIENT_SECRET="${API_CLIENT_SECRET:-local-dev-only-change-me}"

# Compose providers name containers differently (_ or -); the service label is stable.
keycloak_container() {
  podman ps -q --filter label=com.docker.compose.project=betterhome \
    --filter label=com.docker.compose.service=keycloak | head -n 1
}

kcadm() {
  podman exec "$(keycloak_container)" /opt/keycloak/bin/kcadm.sh "$@"
}

kcadm_login() {
  kcadm config credentials --server http://localhost:8180 --realm master \
    --user "$KEYCLOAK_ADMIN_USER" --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null
}

# ensure_user <username> <password> <email> [first] [last]: create the realm user if missing.
ensure_user() {
  local username="$1" password="$2" email="$3" first="${4:-$1}" last="${5:-Demo}"
  kcadm_login
  local existing
  existing="$(kcadm get users -r "$KEYCLOAK_REALM" -q "username=${username}" -q exact=true --fields id --format csv --noquotes)"
  if [[ -z "$existing" ]]; then
    kcadm create users -r "$KEYCLOAK_REALM" -s "username=${username}" -s "email=${email}" \
      -s "firstName=${first}" -s "lastName=${last}" -s enabled=true -s emailVerified=true
    kcadm set-password -r "$KEYCLOAK_REALM" --username "$username" --new-password "$password"
    kcadm add-roles -r "$KEYCLOAK_REALM" --uusername "$username" --rolename member
    echo "keycloak: created user ${username}"
  else
    echo "keycloak: user ${username} exists"
  fi
}

# get_token <username> <password>: password-grant access token printed on stdout.
get_token() {
  curl -fsS -X POST "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
    -d grant_type=password -d "client_id=${API_CLIENT_ID}" -d "client_secret=${API_CLIENT_SECRET}" \
    -d "username=$1" -d "password=$2" | jq -r .access_token
}
