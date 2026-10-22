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
NAS_URL=https://nas.example.ts.net API_CLIENT_SECRET=<betterhome-api secret> \
  SMOKE_USER=<member user> SMOKE_PASSWORD=<its password> make nas-smoke
```

It checks the HTTPS certificate, that Keycloak's issuer is the public URL, that each service is ready through `/api/<service>`, that Gotify answers `/gotify/health`, and that one password-grant token is accepted by all five services. The user must already exist with the `member` role (see First user). It needs `curl` and `jq`.

## The app

Install the APK from `make apk` ([README](../../README.md)), open it and enter the address `https://<host>` (the same host as above). The phone must be on the tailnet.

## Push notifications (Gotify)

Gotify runs in the stack and the phone reaches it at `https://<host>/gotify/` (the trailing slash matters; `/gotify` redirects to it). Push works like this ([ADR 0027](../../documentation/decisions/0027-push-through-gotify.md)): each BetterHome user registers the token of **their own Gotify application**, and notifications-service posts to it. So every person who wants pushes needs a Gotify user, an application, and the Gotify app on their phone.

1. **Create the application.** Open `https://<host>/gotify/`, sign in as `admin` with `CHANGE_ME_GOTIFY_ADMIN_PASSWORD`, go to Apps, Create Application (name it `BetterHome`) and copy its token. For other people, create a Gotify user for each under Users and let them do this with their own login.
2. **Install the Gotify app** on the phone (F-Droid or Play Store), enter the server address `https://<host>/gotify`, and sign in with the Gotify user. In Android's settings for the app, allow it to run in the background without battery restrictions, or messages are delayed. The Tailscale app must be connected for the phone to reach the server (Tailscale's always-on VPN setting keeps it so).
3. **Register the token in BetterHome.** The app has no screen for it yet (T-0086), so call the API once as the BetterHome user (the same `jq` and `curl` work from any machine on the tailnet; `API_CLIENT_SECRET` is the value from your Compose file):

   ```bash
   H=https://nas.example.ts.net
   UT=$(curl -s -X POST $H/auth/realms/betterhome/protocol/openid-connect/token \
     -d grant_type=password -d client_id=betterhome-api -d client_secret=<API_CLIENT_SECRET> \
     -d username=<user> -d password=<password> | jq -r .access_token)
   curl -s -X PUT $H/api/notifications/v1/push-target -H "Authorization: Bearer $UT" \
     -H 'Content-Type: application/json' -d '{"token":"<application token>"}'
   ```

   `DELETE` on the same URL removes it. The token is never returned by the API.
4. **Try it.** In the app, mark a housemate away (needs a second member), or send a test event with the service client (`OIDC_SERVICE_CLIENT_SECRET` from your Compose file). The user's `id` is in `GET $H/api/households/v1/me` and a household id in `GET $H/api/households/v1/households`:

   ```bash
   SVC=$(curl -s -X POST $H/auth/realms/betterhome/protocol/openid-connect/token \
     -d grant_type=client_credentials -d client_id=betterhome-tasks-service \
     -d client_secret=<OIDC_SERVICE_CLIENT_SECRET> | jq -r .access_token)
   curl -s -X POST $H/api/notifications/v1/internal/notifications -H "Authorization: Bearer $SVC" \
     -H 'Content-Type: application/json' \
     -d '{"idempotencyKey":"test-1","householdId":"<household id>","userId":"<user id>","type":"marked_away","payload":{"householdName":"Flat"}}'
   ```

   Change `idempotencyKey` for every test: the same key is stored once. A push arrives on the phone within a second. If it does not, the notification is still in the app's inbox; check the token (a refused token is deleted by the server, register it again) and that the phone is on the tailnet.

## First user

Registration is open in the realm, so a user can sign up from the app's sign-in page. To create one by hand, open `https://<host>/auth` (admin console, user `admin`), realm `betterhome`, Users, and give the user the `member` role.

## Update

Change the tag of the images (`:latest` moves with every merge; pin a commit SHA to be safe) and run `docker compose -f compose.yml up -d` again: the migrations run first, then the services restart on the new images.

## Known limits

- **The realm is imported once**, on the first start with an empty Keycloak database, with the client secrets from the Compose file. Changing them later in the file does not change Keycloak: set the new value in the admin console (realm `betterhome`, Clients, each `betterhome-*-service` client, Credentials) and in the Compose file, then `docker compose up -d`. To start over, remove the `postgres-data` volume (this deletes every household too).
- **One secret for the five service clients**, as in the local stack; a leak of it means regenerating it everywhere.
- **No health checks on the services** (their image has no shell or curl): use the `/q/health/ready` URLs above.
- **Registering the Gotify token** is an API call until the app has a screen for it (T-0086).
