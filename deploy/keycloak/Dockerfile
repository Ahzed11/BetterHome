# Keycloak for the self-hosted stack (deploy/nas, T-0108): production mode behind a reverse proxy, with the
# realm baked in so the NAS needs no checkout. The build-time options below (database, health, the /auth path
# prefix of ADR 0029) cannot be changed at run time; the host name, database URL and passwords can.
# The local stack (deploy/podman-compose.yml) keeps using the stock image in start-dev.
FROM quay.io/keycloak/keycloak:26.0 AS builder
ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_HTTP_RELATIVE_PATH=/auth
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.0
COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY realm-betterhome.json /opt/keycloak/data/import/realm-betterhome.json
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
