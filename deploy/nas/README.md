# BetterHome on a home server (UGREEN NAS)

Runs the five services, Keycloak, Gotify and PostgreSQL with Docker Compose, behind the Caddy that already runs on
the server ([ADR 0029](../../documentation/decisions/0029-caddy-reverse-proxy-on-tailscale.md)). Files:

| File | What it is |
|---|---|
| `compose.yml` | The stack. No Caddy, no Tailscale, no published port, no `.env`: values are inline |
| `Caddyfile` | A snippet for your Caddy: the routes of BetterHome, no host name in it |
| `install.sh` | Fills in every `CHANGE_ME` (host, generated secrets, backup folder), creates the `edge` network and starts the stack |
| `update.sh` | Backs up, moves the images to a tag, pulls and restarts |
| `restore.sh` | Restores one database from a backup |

## Before you start

1. **Caddy and Tailscale** run in your own stack, with the tailnet's HTTPS certificates enabled, and Caddy is on an external Docker network named `edge`. Create it once if needed: `docker network create edge`.
2. **The images are public** on GHCR (`ghcr.io/ahzed11/betterhome-*`). They are built when a pull request is merged into `master` ([ADR 0026](../../documentation/decisions/0026-publish-images-to-ghcr.md)); besides the five services there are `betterhome-migrations` (Flyway with every service's SQL) and `betterhome-keycloak` (production mode, realm baked in), [ADR 0030](../../documentation/decisions/0030-migrations-and-keycloak-images.md).
3. **Your tailnet name** is only ever written on the NAS, never in the repository.

## Install

1. Copy this folder's `compose.yml`, `Caddyfile`, `install.sh`, `update.sh` and `restore.sh` to the NAS (for example `/volume1/docker/betterhome/`), or `git clone` the repository there and work in `deploy/nas`.
2. From SSH in that folder, run the installer with the NAS's name on your tailnet and a folder of a NAS volume for the backups:

   ```bash
   ./install.sh nas.example.ts.net /volume1/backups/betterhome
   ```

   It generates every password and secret (nothing to invent), writes them into `compose.yml` (readable by you only), makes the backup folder writable, creates the `edge` network if it is missing, starts the stack and prints the Keycloak and Gotify admin passwords. Postgres starts, the databases are created, the migrations run, then Keycloak and the services start. `--no-start` fills the file in without starting. It refuses to run a second time, since nothing is left to fill in.
3. In your Caddyfile, add the import inside the site block of your tailnet host, **before** any catch-all `handle` of yours, then reload Caddy (the installer prints the exact line):

   ```
   nas.example.ts.net {
       import /path/to/betterhome.Caddyfile
       # ...your other apps...
   }
   ```

   The snippet only claims `/auth`, `/api/households|tasks|scoring|lists|notifications` and `/gotify`. Check none of them is a route of another app on that host.

The Compose file uses `depends_on: condition: service_completed_successfully`, which needs Docker Compose v2.

<details>
<summary>Without the script (UGOS Docker app, or by hand)</summary>

Replace every `CHANGE_ME_...` in the copy of `compose.yml`, then `docker compose -f compose.yml up -d` (loading the file as a project in the UGOS Docker app should work the same way; that route has not been tried yet):

- `CHANGE_ME_NAS_HOST`: the NAS's name on your tailnet (for example `nas.example.ts.net`). Three places.
- `CHANGE_ME_POSTGRES_PASSWORD`: one strong password, the same value everywhere it appears.
- `CHANGE_ME_KEYCLOAK_ADMIN_PASSWORD` and `CHANGE_ME_GOTIFY_ADMIN_PASSWORD`.
- `CHANGE_ME_BACKUP_DIR`: a folder of a NAS volume for the backups (see Backups). Two places.
- `CHANGE_ME_SERVICE_CLIENT_SECRET` (the same value in the five services and in Keycloak) and `CHANGE_ME_API_CLIENT_SECRET`: long random strings, for example `openssl rand -hex 32`.

Create the network once if needed: `docker network create edge`.

</details>

## Check it

From any machine on the tailnet (replace the host):

```bash
NAS_URL=https://nas.example.ts.net API_CLIENT_SECRET=<betterhome-api secret> \
  SMOKE_USER=<member user> SMOKE_PASSWORD=<its password> make nas-smoke
```

It checks the HTTPS certificate, that Keycloak's issuer is the public URL, that each service is ready through `/api/<service>`, that Gotify answers `/gotify/health`, and that one password-grant token is accepted by all five services. The user must already exist with the `member` role (see First user). It needs `curl` and `jq`.

## The app

Install the APK (the GitHub Release, or `make apk`, see [README](../../README.md#try-the-app-on-a-phone)), open it and enter the address `https://<host>` (the same host as above). The phone must be on the tailnet. On the sign-in page tap "Sign up" to create your account.

## Push notifications (Gotify)

Gotify runs in the stack and the phone reaches it at `https://<host>/gotify/` (the trailing slash matters; `/gotify` redirects to it). Push works like this ([ADR 0027](../../documentation/decisions/0027-push-through-gotify.md)): each BetterHome user registers the token of **their own Gotify application**, and notifications-service posts to it. So every person who wants pushes needs a Gotify user, an application, and the Gotify app on their phone.

1. **Create the application.** Open `https://<host>/gotify/`, sign in as `admin` with `CHANGE_ME_GOTIFY_ADMIN_PASSWORD`, go to Apps, Create Application (name it `BetterHome`) and copy its token. For other people, create a Gotify user for each under Users and let them do this with their own login.
2. **Install the Gotify app** on the phone (F-Droid or Play Store), enter the server address `https://<host>/gotify`, and sign in with the Gotify user. In Android's settings for the app, allow it to run in the background without battery restrictions, or messages are delayed. The Tailscale app must be connected for the phone to reach the server (Tailscale's always-on VPN setting keeps it so).
3. **Register the token in BetterHome.** In the BetterHome app, open the bell, then the notification settings, and paste the application token in the "Push notifications" card (T-0086). "Stop push notifications" there removes it. (Without the app, `PUT $H/api/notifications/v1/push-target` with `{"token":"<application token>"}` and the user's bearer token does the same.)
4. **Try it.** In the app, mark a housemate away (needs a second member), or send a test event with the service client (`OIDC_SERVICE_CLIENT_SECRET` from your Compose file). The user's `id` is in `GET $H/api/households/v1/me` and a household id in `GET $H/api/households/v1/households`:

   ```bash
   H=https://nas.example.ts.net
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

From the folder of `compose.yml` on the NAS:

```bash
./update.sh 3f9c2ab      # a commit SHA tag (the images are tagged with it when a pull request is merged)
./update.sh              # without a tag: pulls the tags already in the file (`:latest` moves with every merge)
```

It first takes a fresh backup of every database (the migrations are forward-only, so this is the way back), rewrites the tag of the BetterHome images in `compose.yml` (the previous file is kept as `compose.yml.before-update`), pulls, and runs `up -d`: the migrations run first, then the services restart. Pin a SHA rather than `:latest` so a rollback is possible: put the old tag back, restore the databases (below) and `up -d`.

## Backups

Two services of the stack do it, no cron needed:

- `backup` dumps the five databases and Keycloak's every night (`pg_dump`, the `prodrigestivill/postgres-backup-local` image used on the server for other stacks). It keeps 7 daily, 4 weekly and 3 monthly files; the newest of each database is `last/<database>-latest.sql.gz`.
- `backup-gotify` archives Gotify's data every 24 hours (`gotify/gotify-<date>.tgz`, 7 kept).

Both write to `CHANGE_ME_BACKUP_DIR` in `compose.yml`: use a folder on a NAS volume, outside the Docker data folder, and make it writable by the container (`chmod 777`, or `chown 999:999`, on the NAS; without it `backup` restarts in a loop with "BACKUP_DIR points to a file or folder with insufficient permissions"). A backup on the same disk does not survive the disk: copy the folder elsewhere with the NAS's own sync or backup tool. Gotify's database is a live SQLite file; a copy taken in the middle of a write could be unusable, which at one dump a day for a handful of users is unlikely and costs only the push registrations (users register their tokens again).

### Restore

Replaces one database entirely. Stop its services first (Postgres refuses to drop a database in use, and then nothing changes):

```bash
docker compose -f compose.yml stop betterhome-tasks
./restore.sh betterhome_tasks /volume1/backups/betterhome/last/betterhome_tasks-latest.sql.gz
docker compose -f compose.yml up -d
```

Database names: `betterhome_households`, `_tasks`, `_scoring`, `_lists`, `_notifications`, `_keycloak` (Keycloak: stop `betterhome-keycloak`). To restore Gotify: `docker compose stop betterhome-gotify`, then `docker run --rm -v betterhome_gotify-data:/data -v <backup dir>:/backups alpine sh -c 'rm -rf /data/* && tar xzf /backups/gotify/gotify-<date>.tgz -C /data'`, then `up -d`.

## Known limits

- **The realm is imported once**, on the first start with an empty Keycloak database, with the client secrets from the Compose file. Changing them later in the file does not change Keycloak: set the new value in the admin console (realm `betterhome`, Clients, each `betterhome-*-service` client, Credentials) and in the Compose file, then `docker compose up -d`. To start over, remove the `postgres-data` volume (this deletes every household too).
- **One secret for the five service clients**, as in the local stack; a leak of it means regenerating it everywhere.
- **No health checks on the services** (their image has no shell or curl): use the `/q/health/ready` URLs above.
