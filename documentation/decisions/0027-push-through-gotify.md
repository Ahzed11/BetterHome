# 0027 — Push notifications are delivered through Gotify

## Context

ADR 0013 put push delivery behind `PushSender` and named FCM / APNs as the vendors. On issue #20 (T-0027) the product owner decided: "Use Gotify for this". Gotify is a self-hosted push server with a REST API (`POST /message` with an application token). It fits the project better than vendor SDKs: no Google or Apple account, no signing, and the server runs next to the services.

Gotify has no device registry we can address. A message goes to the owner of the application token it is posted with, and that owner's Gotify clients (the Gotify Android app, a browser, a script) receive it. So the "device token" of the issue has no direct equivalent: there is nothing to register per device.

## Decision

**Gotify replaces FCM / APNs.** `GotifyPushSender` in notifications-service implements `PushSender`; the seam of ADR 0013 and the outbox/relay flow of ADR 0017 do not change.

**A push target is the user's own Gotify application token.** The user runs or joins a Gotify server, creates an application there, installs a Gotify client, and registers the application token with `PUT /v1/push-target` (also `GET` and `DELETE`). One target per user: Gotify delivers to every client of the token's owner, so several devices need no second registration. The token is write-only: stored in `push_target` (migration V3, constrained to URL-safe characters so it cannot break a header), never returned by the API and never logged. There is no global application token.

**One Gotify server per deployment.** Its base URL comes from `GOTIFY_URL` (`betterhome.gotify.url`). Without it nothing is pushed and the inbox still works, which is also the default for local development and tests.

**Request.** `POST {GOTIFY_URL}/message` with the token in the `X-Gotify-Key` header (Gotify accepts it like `?token=`; a header keeps the secret out of URLs that proxies and access logs record). The body is the rendered `title` and `message`, `priority` 5, and `extras` with a single namespaced key `betterhome::push` holding the notification `type` and the short-string payload entries (IDs and short text, ADR 0017). No user id, email or token is sent.

**Failures.** The notification is stored before the push is attempted, so a failure never reaches the caller. A 401, 403 or 404 means the token is unknown or revoked: the target is deleted, but only if it still holds the refused token (a newer registration is kept). Other statuses (400, 5xx), timeouts and connection errors are logged and the push is dropped; the target stays. Logs carry the type and status, never the token, title or body (AGENTS §8). Delivery stays at most once, as in ADR 0017; retries are a follow-up.

## Consequences

- AGENTS §1 and §3, spec §5 and the architecture figure now say Gotify. ADR 0013 stays as the record of the seam; its mention of FCM / APNs is superseded by this one.
- Users need a Gotify account and app. Self-registration of the token is a deliberate manual step; automating it (the Gotify user API needs the user's Gotify credentials) is not planned.
- The token is stored in clear text in the notifications database, like any credential the service must replay. It can only send messages to that one user's Gotify application. Column encryption is a follow-up if the database is ever shared more widely.
- T-0086 (app registration) becomes "let the user paste or scan the application token and register it", not an OS permission prompt.
- The local Compose stack has an optional `gotify` profile for trying delivery by hand.
