# 0017 — Notification event contract and ownership

## Context

Spec §5 and §6.2 describe notifications and per-type preferences. Other services (tasks, households) know when something noteworthy happened, but they must not render text, read preferences or talk to a push vendor (ADR 0013). T-0026 will move their outboxes onto this contract, so the contract has to be settled first.

## Decision

**Ownership.** notifications-service owns the `notification` and `notification_preference` tables. No other service reads them. Notifications are tied to our `USER.id` only; the token subject is mapped to it through households-service.

**Event.** A producer sends `POST /v1/internal/notifications` with the `service` role (ADR 0014):

| Field | Rule |
|---|---|
| `idempotencyKey` | Required, at most 200 characters, unique per event across all producers, for example `tasks:<outbox row id>`. |
| `householdId`, `userId` | Required. `userId` is our `USER.id` of the recipient. |
| `type` | One of the spec §5 types: `task_assigned`, `task_reassigned`, `due_reminder`, `overdue`, `dismissed`, `superseded`, `reverted`, `marked_away`, `invitation`. Anything else is a 400. |
| `payload` | Map of short strings (at most 10 entries, 200 characters each): IDs and the text the message needs. `taskTitle` is required for every task type, `householdName` for `invitation`, nothing for `marked_away`. A missing required key is a 400. |
| `localeHint` | Optional `en` or `fr`. Used only when households-service does not know the user. |

The answer is 201 `created`, or 200 `duplicate` (the key was already stored; the existing notification is returned) or 200 `suppressed` (the recipient switched the type off on every channel). A producer treats any 2xx as delivered and retries on 5xx, so delivery is at least once and storage is exactly once.

**Storage.** One row per channel (`push`, `in_app`), unique on `(idempotency_key, channel)`. Inserts use `ON CONFLICT DO NOTHING`, so concurrent deliveries of one event store it once. The `in_app` rows are the inbox. A `push` row records what was handed to the `PushSender`, which is called only after the row is committed. If the sender fails, a retry returns `duplicate` and does not push again: push is at most once until T-0027 adds delivery state and retries. A `CHECK` constraint on type and channel mirrors the Java enums; adding a channel such as email is one migration.

**Rendering.** Title and body are rendered when the event arrives, from `i18n/notifications_<lang>.properties` (`<type>.title`, `<type>.body`, placeholders like `{taskTitle}`), in the recipient's language and stored as text. Plain `ResourceBundle` was chosen over Qute or `MessageFormat`: the texts are short, need no logic, and `MessageFormat` makes the apostrophe in French a trap. A test fails when any type lacks either language. The language is the one in the user's households profile (`GET /v1/internal/users/{userId}`); if households does not know the user, the `localeHint`, else `en`. If households is unreachable, ingest answers 503 and stores nothing, so the producer retries; a wrong language is never stored silently. Changing the profile language later does not rewrite old notifications.

**Preferences.** Per user (not per household), per type and channel, all enabled by default; no row means enabled. A disabled type/channel is simply not created: no row, no push. Disabling both channels of a type makes the event `suppressed`. The spec says only that "users can toggle each notification type"; per-user scope and the per-channel grid are our reading, and they can be refined without changing the event contract.

**App API.** Authenticated users list their inbox (filters `householdId`, `unreadOnly`; paging with `limit` and `before=<id of the last item>`), mark one or all read, and read or update preferences. No endpoint takes a user id: queries are scoped to the caller. Another user's notification answers 404, the same as a missing one.

## Consequences

- T-0026 relays send this event instead of calling `PushSender` directly; the title and body columns of tasks' outbox become unnecessary.
- notifications-service depends on households-service for two lookups (user by subject, user by id), added as read-only `service` endpoints there. Households being down means 503 for the inbox and for ingest.
- Payloads must stay free of personal data beyond short task and household names.
