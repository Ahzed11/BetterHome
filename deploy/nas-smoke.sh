#!/usr/bin/env bash
# Smoke check for the self-hosted stack (deploy/nas, T-0112), run from any machine on the tailnet:
# the HTTPS certificate is valid, Keycloak's issuer is the public URL, every service is ready through its
# prefix, Gotify is healthy, and one password-grant token is accepted by every service.
# The address is never committed: NAS_URL=https://<host> make nas-smoke
set -euo pipefail

: "${NAS_URL:?set NAS_URL to the public address, for example https://nas.example.ts.net}"
: "${API_CLIENT_SECRET:?set API_CLIENT_SECRET to the secret of the betterhome-api client (compose.yml)}"
: "${SMOKE_USER:?set SMOKE_USER to an existing realm user with the member role}"
: "${SMOKE_PASSWORD:?set SMOKE_PASSWORD to the password of that user}"
base="${NAS_URL%/}"
realm="${KEYCLOAK_REALM:-betterhome}"
client="${API_CLIENT_ID:-betterhome-api}"
services=(households tasks scoring lists notifications)

# curl verifies the certificate and the host name; a failure here is the certificate check.
if ! curl -fsS -o /dev/null "$base/auth/realms/$realm/.well-known/openid-configuration"; then
  echo "nas-smoke: $base is unreachable or its certificate is not valid" >&2
  exit 1
fi
echo "nas-smoke: certificate valid, Keycloak reachable"

issuer="$(curl -fsS "$base/auth/realms/$realm/.well-known/openid-configuration" | jq -r .issuer)"
if [[ "$issuer" != "$base/auth/realms/$realm" ]]; then
  echo "nas-smoke: issuer is '$issuer', expected '$base/auth/realms/$realm' (KC_HOSTNAME or the proxy headers)" >&2
  exit 1
fi
echo "nas-smoke: issuer matches the public URL"

for service in "${services[@]}"; do
  curl -fsS -o /dev/null "$base/api/$service/q/health/ready" \
    || { echo "nas-smoke: $service is not ready through /api/$service" >&2; exit 1; }
  echo "nas-smoke: $service ready"
done
curl -fsS -o /dev/null "$base/gotify/health" || { echo "nas-smoke: Gotify health failed at /gotify/health" >&2; exit 1; }
echo "nas-smoke: gotify healthy"

token="$(curl -fsS -X POST "$base/auth/realms/$realm/protocol/openid-connect/token" \
  -d grant_type=password -d "client_id=$client" --data-urlencode "client_secret=$API_CLIENT_SECRET" \
  --data-urlencode "username=$SMOKE_USER" --data-urlencode "password=$SMOKE_PASSWORD" | jq -r .access_token)"
if [[ -z "$token" || "$token" == "null" ]]; then
  echo "nas-smoke: no access token for $SMOKE_USER" >&2
  exit 1
fi
# The same token must be accepted by every service (shared issuer, shared audience).
for service in "${services[@]}"; do
  curl -fsS -o /dev/null -H "Authorization: Bearer $token" "$base/api/$service/v1/meta" \
    || { echo "nas-smoke: $service refused the Keycloak token" >&2; exit 1; }
  echo "nas-smoke: $service accepted the token"
done
echo "nas-smoke: OK"
