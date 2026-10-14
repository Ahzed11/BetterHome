-- Spec §5 and §6.2: NOTIFICATION and PREFERENCE, owned by notifications-service.
-- One row per delivery channel of an event. The in_app rows are the inbox; push rows record what
-- was handed to the push gateway.

CREATE TABLE notification (
    id               UUID PRIMARY KEY,
    household_id     UUID NOT NULL,
    user_id          UUID NOT NULL,
    type             TEXT NOT NULL,
    channel          TEXT NOT NULL,
    title            TEXT NOT NULL,
    body             TEXT NOT NULL,
    payload          JSONB NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key  TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL,
    read_at          TIMESTAMPTZ,
    CONSTRAINT notification_type_chk CHECK (
        type IN (
            'task_assigned',
            'task_reassigned',
            'due_reminder',
            'overdue',
            'dismissed',
            'superseded',
            'reverted',
            'marked_away',
            'invitation'
        )
    ),
    CONSTRAINT notification_channel_chk CHECK (channel IN ('push', 'in_app')),
    CONSTRAINT notification_title_chk CHECK (char_length(trim(title)) > 0),
    CONSTRAINT notification_body_chk CHECK (char_length(trim(body)) > 0),
    CONSTRAINT notification_key_chk CHECK (char_length(trim(idempotency_key)) > 0),
    CONSTRAINT notification_payload_chk CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT notification_event_channel_uq UNIQUE (idempotency_key, channel)
);

CREATE INDEX notification_inbox_idx
    ON notification (user_id, created_at DESC, id DESC)
    WHERE channel = 'in_app';

CREATE TABLE notification_preference (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    type        TEXT NOT NULL,
    channel     TEXT NOT NULL,
    enabled     BOOLEAN NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL,
    CONSTRAINT notification_preference_type_chk CHECK (
        type IN (
            'task_assigned',
            'task_reassigned',
            'due_reminder',
            'overdue',
            'dismissed',
            'superseded',
            'reverted',
            'marked_away',
            'invitation'
        )
    ),
    CONSTRAINT notification_preference_channel_chk CHECK (channel IN ('push', 'in_app')),
    CONSTRAINT notification_preference_uq UNIQUE (user_id, type, channel)
);
