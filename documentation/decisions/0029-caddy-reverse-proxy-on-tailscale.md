# 0029 — One Caddy reverse proxy in front of the self-hosted stack, reached through Tailscale

## Context

The stack has so far run only on the development machine (`make up`, `localhost` URLs, Keycloak in `start-dev`). To try the app on a phone, the backend now also runs on a home NAS (UGREEN, x86_64, Docker Compose, T-0108). The phone reaches it from anywhere, but nothing may be exposed to the internet. The app talks to six HTTP endpoints today (Keycloak and five services) and signs in with OIDC, which needs one issuer URL that the app, the services and Keycloak itself all see identically (ADR 0005). Android blocks cleartext HTTP by default, and Keycloak refuses plain HTTP outside `localhost`. The tailnet name is personal: it must not appear in the repository, and the F-Droid repository the app will be published through is public (T-0115, T-0117).

## Decision

**Caddy is the only published service of the NAS stack** and the single HTTPS entry point. It listens on one host name that comes from configuration (`NAS_HOST`, in the uncommitted `deploy/nas/.env`). The repository only holds the placeholder `nas.example.ts.net`.

**Routing is by path on that one host**, because Tailscale's MagicDNS gives a machine one name and no subdomains. Caddy strips the prefix for the services:

| Path | Goes to | Notes |
|---|---|---|
| `/auth/*` | `keycloak:8180` | Keycloak runs with `KC_HTTP_RELATIVE_PATH=/auth`, so the prefix is kept |
| `/api/households/*`, `/api/tasks/*`, `/api/scoring/*`, `/api/lists/*`, `/api/notifications/*` | `<service>:808x` | Only `/v1/*` and `/q/health/*` are forwarded; the rest of a service's management surface answers 404 |
| `/gotify/*` | `gotify:80` | Gotify supports a sub-path behind a proxy; Caddy forwards its WebSocket (`/gotify/stream`) without extra settings |
| anything else | 404 | |

**The app needs one base URL.** From `https://<host>` it derives the issuer `https://<host>/auth/realms/betterhome` and the service URLs `https://<host>/api/<service>`. Entering it in the app is T-0115; the build-time `--dart-define`s stay as the default so development and e2e do not change. Service-to-service calls and Keycloak's back channel stay on the Compose network and never go through Caddy.

**TLS comes from Tailscale.** The host is the machine's `ts.net` name, Caddy obtains its certificate through tailscaled (the socket is shared with Caddy, T-0110), and Android trusts it with no CA to install. If Tailscale HTTPS is not wanted, the fallback is `tls internal` with Caddy's root CA installed on the phone.

**Keycloak behind the proxy** runs in production mode (`start`, its own Postgres database) with `KC_HOSTNAME=https://<host>/auth`, `KC_PROXY_HEADERS=xforwarded` and `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true`. As in `deploy/podman-compose.yml`, services reach it as `http://keycloak:8180/auth/realms/betterhome` while the `iss` of every token is the public URL, so issuer validation stays on (T-0109).

**Gotify** is reached by the phone at `https://<host>/gotify` and by notifications-service at `GOTIFY_URL=http://gotify:80` (ADR 0027, T-0114).

**Access control is the tailnet.** Only the phone and the development machine are allowed by ACL; Tailscale Funnel stays off and no port is forwarded on the router. Secrets (database and Keycloak admin passwords, the service-client secrets, the Tailscale auth key) come only from `.env`.

### Alternatives not chosen

- **Subdomains per service.** MagicDNS has none; it would need a domain of our own and DNS for it.
- **A public domain with Let's Encrypt.** Exposes Keycloak and the APIs to the internet and needs a forwarded port, for a test setup.
- **One port per service.** The app would carry six URLs and the certificate would have to cover each port.
- **Plain HTTP over the tailnet.** WireGuard already encrypts it, but Android blocks cleartext by default and Keycloak refuses HTTP on a non-local host.
- **`tailscale serve` instead of Caddy.** It can route paths too, but the project chose Caddy for header control and one Caddyfile that also works without Tailscale.

## Consequences

- One host name binds every token (`iss`): changing `NAS_HOST` signs everyone out.
- The paths above are a contract between the Caddyfile (T-0108), the app's URL derivation (T-0115) and the smoke check (T-0112); a change to one changes all three.
- Tailscale HTTPS certificates are issued by a public CA, so their host name (machine and tailnet name) is written to public Certificate Transparency logs. It stays out of the repository, but it is not secret. `tls internal` avoids it, at the cost of installing a root CA on the phone.
- Caddy is a single point of failure for the stack; there is no high availability, which is fine for testing.
- Caddy in the development `make up` stack is not part of this decision.
