-- The outbox now relays events to notifications-service (ADR 0017, T-0026). It carries the event
-- type and a payload of short strings; the text is rendered there. Expand step only: title and body
-- stay as nullable columns that are no longer written, and a later migration drops them.

ALTER TABLE notification_outbox
    ALTER COLUMN title DROP NOT NULL,
    ALTER COLUMN body DROP NOT NULL,
    ADD COLUMN attempts INT NOT NULL DEFAULT 0,
    ADD COLUMN available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN failed_at TIMESTAMPTZ,
    ADD CONSTRAINT notification_outbox_attempts_chk CHECK (attempts >= 0),
    ADD CONSTRAINT notification_outbox_state_chk CHECK (
        processed_at IS NULL OR failed_at IS NULL
    );

-- Rows still waiting carry the chore title in `body`; the event needs it as `taskTitle`.
UPDATE notification_outbox
SET payload_json = jsonb_set(payload_json::jsonb, '{taskTitle}', to_jsonb(body))::text
WHERE processed_at IS NULL
  AND body IS NOT NULL;

-- Relays claim the oldest due row that is neither delivered nor parked.
CREATE INDEX notification_outbox_due_idx
    ON notification_outbox (available_at, created_at)
    WHERE processed_at IS NULL AND failed_at IS NULL;
