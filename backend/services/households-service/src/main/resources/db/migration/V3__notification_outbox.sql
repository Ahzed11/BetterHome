-- Events for notifications-service (ADR 0017, T-0026), written in the transaction of the change that
-- causes them and relayed at least once. households produces only these two types.

CREATE TABLE notification_outbox (
    id              UUID PRIMARY KEY,
    household_id    UUID NOT NULL REFERENCES household (id),
    user_id         UUID NOT NULL REFERENCES app_user (id),
    type            TEXT NOT NULL,
    payload_json    TEXT NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL,
    processed_at    TIMESTAMPTZ,
    attempts        INT NOT NULL DEFAULT 0,
    available_at    TIMESTAMPTZ NOT NULL,
    failed_at       TIMESTAMPTZ,
    CONSTRAINT notification_outbox_type_chk CHECK (type IN ('marked_away', 'invitation')),
    CONSTRAINT notification_outbox_attempts_chk CHECK (attempts >= 0),
    CONSTRAINT notification_outbox_state_chk CHECK (processed_at IS NULL OR failed_at IS NULL)
);

-- Relays claim the oldest due row that is neither delivered nor parked.
CREATE INDEX notification_outbox_due_idx
    ON notification_outbox (available_at, created_at)
    WHERE processed_at IS NULL AND failed_at IS NULL;
