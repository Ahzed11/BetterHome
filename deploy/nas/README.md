# BetterHome on a home server (UGREEN NAS)

Runs the five services, Keycloak, Gotify and PostgreSQL with Docker Compose, behind the Caddy that already runs on
the server ([ADR 0029](../../documentation/decisions/0029-caddy-reverse-proxy-on-tailscale.md)). Files:

| File | What it is |
|---|---|
| `compose.yml` | The stack. No Caddy, no Tailscale, no published port, no `.env`: values are inline |
| `Caddyfile` | A snippet for your Caddy: the routes of BetterHome, no host name in it |

## Before you start

1. **Caddy and Tailscale** run in your own stack, with the tailnet's HTTPS certificates enabled, and Caddy is on an external Docker network named `edge`. Create it once if needed: `docker network create edge`.
2. **The images are public** on GHCR (`ghcr.io/ahzed11/betterhome-*`). They are built when a pull request is merged into `master` ([ADR 0026](../../documentation/decisions/0026-publish-images-to-ghcr.md)); besides the five services there are `betterhome-migrations` (Flyway with every service's SQL) and `betterhome-keycloak` (production mode, realm baked in), [ADR 0030](../../documentation/decisions/0030-migrations-and-keycloak-images.md).
3. **Your tailnet name** is only ever written on the NAS, never in the repository.

## Install

1. Copy `compose.yml` and `Caddyfile` to the NAS (for example to `/volume1/docker/betterhome/`).
2. In the copy of `compose.yml`, replace every `CHANGE_ME_...`:
   - `CHANGE_ME_NAS_HOST`: the NAS's name on your tailnet (for example `nas.example.ts.net`). Three places.
   - `CHANGE_ME_POSTGRES_PASSWORD`: one strong password, the same value everywhere it appears.
   - `CHANGE_ME_KEYCLOAK_ADMIN_PASSWORD` and `CHANGE_ME_GOTIFY_ADMIN_PASSWORD`.
   - `CHANGE_ME_SERVICE_CLIENT_SECRET` (the same value in the five services and in Keycloak) and `CHANGE_ME_API_CLIENT_SECRET`: long random strings, for example `openssl rand -hex 32`.
3. In your Caddyfile, add the import inside the site block of your tailnet host, **before** any catch-all `handle` of yours, then reload Caddy:

   ```
   nas.example.ts.net {
       import /path/to/betterhome.Caddyfile
       # ...your other apps...
   }
   ```

   The snippet only claims `/auth`, `/api/households|tasks|scoring|lists|notifications` and `/gotify`. Check none of them is a route of another app on that host.
4. Start it, from SSH: `docker compose -f compose.yml up -d`. Postgres starts, the databases are created, the migrations run, then Keycloak and the services start. (Loading the file as a project in the UGOS Docker app should work the same way; that route has not been tried yet.)

The Compose file uses `depends_on: condition: service_completed_successfully`, which needs Docker Compose v2.

## Check it

From any machine on the tailnet (replace the host):

```bash
H=https://nas.example.ts.net
curl -s $H/auth/realms/betterhome/.well-known/openid-configuration | jq -r .issuer   # https://<host>/auth/realms/betterhome
for s in households tasks scoring lists notifications; do curl -s -o /dev/null -w "$s %{http_code}\n" $H/api/$s/q/health/ready; done
curl -s $H/gotify/health
```

## The app

Install the APK from `make apk` ([README](../../README.md)), open it and enter the address `https://<host>` (the same host as above). The phone must be on the tailnet.

## First user

Registration is open in the realm, so a user can sign up from the app's sign-in page. To create one by hand, open `https://<host>/auth` (admin console, user `admin`), realm `betterhome`, Users, and give the user the `member` role.

## Update

Change the tag of the images (`:latest` moves with every merge; pin a commit SHA to be safe) and run `docker compose -f compose.yml up -d` again: the migrations run first, then the services restart on the new images.

## Known limits

- **The realm is imported once**, on the first start with an empty Keycloak database, with the client secrets from the Compose file. Changing them later in the file does not change Keycloak: set the new value in the admin console (realm `betterhome`, Clients, each `betterhome-*-service` client, Credentials) and in the Compose file, then `docker compose up -d`. To start over, remove the `postgres-data` volume (this deletes every household too).
- **One secret for the five service clients**, as in the local stack; a leak of it means regenerating it everywhere.
- **No health checks on the services** (their image has no shell or curl): use the `/q/health/ready` URLs above.
- **Push** needs the application token of each user in Gotify; see T-0114 and T-0086.
