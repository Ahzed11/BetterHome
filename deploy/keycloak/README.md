# Keycloak local realm

`realm-betterhome.json` is imported on first `make up`. It defines the `betterhome` realm, `admin` / `member` / `service` roles, and the `betterhome-api` / `betterhome-app` / `betterhome-tasks-service` / `betterhome-scoring-service` / `betterhome-lists-service` / `betterhome-notifications-service` clients. The four service clients use client credentials; their service accounts hold the `service` role that unlocks households-service's internal endpoints (tasks, scoring, lists, notifications), scoring-service's award and reverse endpoints (tasks) and notifications-service's event ingest. It does **not** contain user passwords.

## Create a local demo user

After Keycloak is up (`http://localhost:8180`, admin console credentials from Compose env):

```bash
podman exec -it $(podman ps -qf name=keycloak) \
  /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8180 --realm master --user admin --password admin

podman exec -it $(podman ps -qf name=keycloak) \
  /opt/keycloak/bin/kcadm.sh create users -r betterhome \
  -s username=demo -s email=demo@betterhome.local -s enabled=true -s emailVerified=true

podman exec -it $(podman ps -qf name=keycloak) \
  /opt/keycloak/bin/kcadm.sh set-password -r betterhome --username demo --new-password demo

podman exec -it $(podman ps -qf name=keycloak) \
  /opt/keycloak/bin/kcadm.sh add-roles -r betterhome --uusername demo --rolename member
```

Never commit real passwords, production realm exports, or client secrets.
