# BetterHome on a home server (UGREEN NAS)

Runs the five services, Keycloak, Gotify and PostgreSQL with Docker Compose, behind the Caddy that already runs on
the server ([ADR 0029](../../documentation/decisions/0029-caddy-reverse-proxy-on-tailscale.md)). Files:

| File | What it is |
|---|---|
| `compose.yml` | The stack. No Caddy, no Tailscale, no published port, no `.env`: values are inline |
| `Caddyfile` | A snippet for your Caddy: the routes of BetterHome, no host name in it |
| `update.sh` | SSH only: backs up, moves the images to a tag, pulls and restarts |
| `restore.sh` | SSH only: restores one database from a backup |

## Before you start

1. **Caddy and Tailscale** run in your own stack, with the tailnet's HTTPS certificates enabled, and Caddy is on an external Docker network named `edge`. See Install, step 3, if it does not exist.
2. **The images are public** on GHCR (`ghcr.io/ahzed11/betterhome-*`). They are built when a pull request is merged into `master` ([ADR 0026](../../documentation/decisions/0026-publish-images-to-ghcr.md)); besides the five services there are `betterhome-migrations` (Flyway with every service's SQL) and `betterhome-keycloak` (production mode, realm baked in), [ADR 0030](../../documentation/decisions/0030-migrations-and-keycloak-images.md).
3. **Your tailnet name** is only ever written on the NAS, never in the repository.

## Install

This is done in the UGOS web interface, from a browser: no SSH needed. (UGOS menu names change between versions; where a label below differs on your NAS, the idea is the same. The same steps work with `docker compose` over SSH, see the end of this section.)

1. **Prepare the file on your computer.** Download `compose.yml` and `Caddyfile` from this folder (on GitHub: open the file, then "Raw", then save). Open `compose.yml` in a text editor and use find and replace to fill in every `CHANGE_ME_...`. The same name always gets the same value:

   | Placeholder | Value | Places |
   |---|---|---|
   | `CHANGE_ME_NAS_HOST` | The NAS's name on your tailnet, for example `nas.example.ts.net` | 3 |
   | `CHANGE_ME_POSTGRES_PASSWORD` | A generated secret | every one |
   | `CHANGE_ME_KEYCLOAK_ADMIN_PASSWORD` | A password for the Keycloak admin console | 1 |
   | `CHANGE_ME_GOTIFY_ADMIN_PASSWORD` | A password for the Gotify admin | 1 |
   | `CHANGE_ME_SERVICE_CLIENT_SECRET` | A generated secret, shared by the five services and Keycloak | every one |
   | `CHANGE_ME_API_CLIENT_SECRET` | A generated secret (for scripts and checks) | 1 |
   | `CHANGE_ME_BACKUP_DIR` | The path of the backup folder from step 2, for example `/volume1/backups/betterhome` | 2 |

   Generate each secret with your password manager: 40 characters, **letters and digits only** (a `#`, `&`, `:` or quote breaks the file or the database URL). Write the values in your password manager: the file on the NAS is the only other place they exist. Never commit or share the edited file.
2. **Create the backup folder.** In the Files app, create a folder on a NAS volume (for example `backups/betterhome`), outside the Docker folder. Its path as Docker sees it is `/volume1/...` (the volume number is the one of your NAS). The backup container writes as user `999`; if the `backup` container restarts in a loop with "insufficient permissions" (see its logs), give the folder read and write rights to everyone, or ask for help with an SSH `chown 999:999`.
3. **Check the `edge` network.** In the Docker app open Network. If your Caddy stack already runs, a network named `edge` exists. If not, create one named `edge` (bridge). The BetterHome project joins it so your Caddy can reach the containers.
4. **Create the project.** In the Docker app open Project, then Create. Name it `betterhome`, choose a folder for it (for example `docker/betterhome`), and give the edited `compose.yml` (upload the file, or paste its content in the editor). Deploy it. Postgres starts, the databases are created, the migrations run, then Keycloak and the services start. The first start takes a few minutes while the images are pulled. In Containers, wait until every `betterhome-*` container runs; `init-databases` and `migrate` stop by themselves once done, which is normal. If one restarts in a loop, open its logs.
5. **Let your Caddy serve it.** Open the Caddyfile of your existing Caddy (in the Files app, in the folder of its project) and add the content of this folder's `Caddyfile` inside the site block of your tailnet host, **before** any catch-all `handle` of yours, or save the file next to your Caddyfile and `import` it:

   ```
   nas.example.ts.net {
       import /path/to/betterhome.Caddyfile
       # ...your other apps...
   }
   ```

   Then restart the Caddy container (Containers, Restart). The snippet only claims `/auth`, `/api/households|tasks|scoring|lists|notifications` and `/gotify`. Check none of them is a route of another app on that host. The path of an `import` is the one **inside** the Caddy container, so the file must be in a folder the container mounts.
6. **Check it** with the next section.

The Compose file needs Docker Compose v2 (`depends_on: condition: service_completed_successfully`), which current UGOS versions use. Not yet tried on a UGREEN NAS: report what differs.

<details>
<summary>With SSH instead</summary>

Put `compose.yml` and `Caddyfile` in a folder, fill the placeholders (`openssl rand -hex 32` makes secrets), `mkdir -p` the backup folder with `chmod 777`, `docker network create edge` if it does not exist, then:

```bash
docker compose -f compose.yml up -d
docker compose -f compose.yml ps        # init-databases and migrate "exited (0)", the rest running
docker compose -f compose.yml logs -f
```

</details>

## Check it

Open these addresses in the browser of a device on the tailnet (replace the host). Each must show `"status": "UP"` (or `ok` for Gotify):

- `https://nas.example.ts.net/api/households/q/health/ready`, and the same for `tasks`, `scoring`, `lists` and `notifications`
- `https://nas.example.ts.net/gotify/health`
- `https://nas.example.ts.net/auth/realms/betterhome/.well-known/openid-configuration`: its `issuer` must be `https://nas.example.ts.net/auth/realms/betterhome`

A certificate warning means Tailscale HTTPS certificates are not enabled for the host. If you can run commands from a computer, `make nas-smoke` (in the repository) does all of this and one sign-in:

```bash
NAS_URL=https://nas.example.ts.net API_CLIENT_SECRET=<betterhome-api secret> \
  SMOKE_USER=<member user> SMOKE_PASSWORD=<its password> make nas-smoke
```

It needs `curl` and `jq`, and a user that already exists with the `member` role (see First user).

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

**In the UGOS interface:** in the Docker app open the project, make sure last night's backup exists in the backup folder (the migrations are forward-only, so a backup is the way back), then pull the new images and redeploy the project (the project's update or rebuild action; if your version has none, stop the project, delete the BetterHome images in Images, and start it again, which pulls them). The migrations run first, then the services restart. To pin a version, change the tag of the seven `ghcr.io/ahzed11/betterhome-*` images in the project's `compose.yml` from `:latest` to a commit SHA tag, and keep the old file so you can go back.

**With SSH**, from the folder of `compose.yml` on the NAS:

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

Restoring runs `psql` inside the Postgres container, which the interface alone does not offer. Either enable SSH on the NAS for the time of the restore, or open a terminal on the `postgres` container if your UGOS version has one, and run what `restore.sh` does: drop and recreate the database, then load the dump with `gunzip -c <dump> | psql -U betterhome -d <database>` (the dump must be reachable from the container; `restore.sh` reads the file on the host). With SSH it is one script. It replaces one database entirely. Stop its services first (Postgres refuses to drop a database in use, and then nothing changes):

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
