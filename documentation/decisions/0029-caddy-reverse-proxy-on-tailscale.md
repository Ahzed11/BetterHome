# 0029 — The NAS's Caddy reverse proxy fronts the self-hosted stack, reached through Tailscale

## Context

The stack has so far run only on the development machine (`make up`, `localhost` URLs, Keycloak in `start-dev`). To try the app on a phone, the backend now also runs on a home NAS (UGREEN, x86_64, Docker Compose, T-0108). That NAS already runs Caddy and Tailscale in a Compose stack of their own, shared with the other apps on it, and joined to the other stacks through an external Docker network named `edge`. NAS Docker UIs often cannot load a `.env` file, so the operator's stacks inline their values and edit them on the NAS. The phone reaches it from anywhere, but nothing may be exposed to the internet. The app talks to six HTTP endpoints today (Keycloak and five services) and signs in with OIDC, which needs one issuer URL that the app, the services and Keycloak itself all see identically (ADR 0005). Android blocks cleartext HTTP by default, and Keycloak refuses plain HTTP outside `localhost`. The tailnet name is personal: it must not appear in the repository, and the F-Droid repository the app will be published through is public (T-0115, T-0117).

## Decision

**BetterHome does not ship its own Caddy or Tailscale.** The NAS's existing Caddy stays the single HTTPS entry point, so the operator keeps the freedom to run other services on the same machine. The repository provides:

- a **Caddyfile snippet** (`deploy/nas/Caddyfile`, T-0108) with no host name in it, which the operator `import`s inside the site block of the tailnet host. It only claims the paths below and has no catch-all, so it coexists with the routes of other apps on that host;
- a **Compose file** (`deploy/nas/compose.yml`) whose gateway-facing containers (the five services, Keycloak, Gotify) also join the external `edge` network under `betterhome-*` aliases, so Caddy reaches them by name and a generic name such as `keycloak` cannot collide with another stack. Postgres and the Flyway jobs stay on the stack's private network.

The host name is the operator's tailnet name. It is configuration on the NAS, never in the repository: where the stack needs it (Keycloak's public URL), the committed files hold the placeholder `CHANGE_ME_NAS_HOST` (examples use `nas.example.ts.net`) that is edited on the NAS, like the other `CHANGE_ME` values.

**Routing is by path on that one host**, because Tailscale's MagicDNS gives a machine one name and no subdomains. Caddy strips the prefix for the services:

| Path | Goes to | Notes |
|---|---|---|
| `/auth/*` | `keycloak:8180` | Keycloak runs with `KC_HTTP_RELATIVE_PATH=/auth`, so the prefix is kept |
| `/api/households/*`, `/api/tasks/*`, `/api/scoring/*`, `/api/lists/*`, `/api/notifications/*` | `<service>:808x` | Only `/v1/*` and `/q/health/*` are forwarded; the rest of a service's management surface answers 404 from the snippet |
| `/gotify/*` | `gotify:80` | Gotify supports a sub-path behind a proxy; Caddy forwards its WebSocket (`/gotify/stream`) without extra settings |
| anything else | not claimed | left to the operator's own site and other apps |

**The app needs one base URL.** From `https://<host>` it derives the issuer `https://<host>/auth/realms/betterhome` and the service URLs `https://<host>/api/<service>`. Entering it in the app is T-0115; the build-time `--dart-define`s stay as the default so development and e2e do not change. Service-to-service calls and Keycloak's back channel stay on the Compose network and never go through Caddy.

**TLS comes from Tailscale.** The host is the machine's `ts.net` name, the NAS's Caddy obtains its certificate through tailscaled, and Android trusts it with no CA to install. T-0110 documents what is needed (HTTPS certificates enabled in the tailnet, Caddy allowed to use tailscaled). If Tailscale HTTPS is not wanted, the fallback is `tls internal` with Caddy's root CA installed on the phone.

**Keycloak behind the proxy** runs in production mode (`start`, its own Postgres database) with `KC_HOSTNAME=https://<host>/auth`, `KC_PROXY_HEADERS=xforwarded` and `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true`. As in `deploy/podman-compose.yml`, services reach it as `http://keycloak:8180/auth/realms/betterhome` while the `iss` of every token is the public URL, so issuer validation stays on (T-0109).

**Gotify** is reached by the phone at `https://<host>/gotify` and by notifications-service at `GOTIFY_URL=http://gotify:80` (ADR 0027, T-0114). Its container joins `edge` as `betterhome-gotify`.

**Access control is the tailnet.** Only the phone and the development machine are allowed by ACL; Tailscale Funnel stays off and no port is forwarded on the router. Secrets (database and Keycloak admin passwords, the service-client secrets) are `CHANGE_ME` placeholders in the committed Compose file, replaced with real values only in the copy on the NAS.

**Images** are pulled from GHCR (ADR 0026). The product owner makes the packages public, so the NAS needs no registry login.

### Alternatives not chosen

- **Subdomains per service.** MagicDNS has none; it would need a domain of our own and DNS for it.
- **A public domain with Let's Encrypt.** Exposes Keycloak and the APIs to the internet and needs a forwarded port, for a test setup.
- **One port per service.** The app would carry six URLs and the certificate would have to cover each port.
- **Plain HTTP over the tailnet.** WireGuard already encrypts it, but Android blocks cleartext by default and Keycloak refuses HTTP on a non-local host.
- **Caddy and Tailscale inside the BetterHome stack.** It would duplicate the proxy the NAS already runs, put two proxies on port 443 and remove the flexibility to host other services behind the same entry point.
- **`tailscale serve` instead of Caddy.** It can route paths too, but the project chose Caddy for header control and one Caddyfile that also works without Tailscale.

## Consequences

- One host name binds every token (`iss`): changing the host name signs everyone out.
- The paths above are a contract between the Caddyfile (T-0108), the app's URL derivation (T-0115) and the smoke check (T-0112); a change to one changes all three.
- Tailscale HTTPS certificates are issued by a public CA, so their host name (machine and tailnet name) is written to public Certificate Transparency logs. It stays out of the repository, but it is not secret. `tls internal` avoids it, at the cost of installing a root CA on the phone.
- The NAS's Caddy and the `edge` network are prerequisites: the BetterHome stack does not start without the network, and its snippet must be imported by hand. T-0108 checks the paths do not overlap with the routes of other apps on the host.
- Caddy is a single point of failure for the stack; there is no high availability, which is fine for testing.
- Caddy in the development `make up` stack is not part of this decision.
