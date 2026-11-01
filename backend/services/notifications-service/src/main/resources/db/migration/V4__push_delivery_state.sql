-- Push delivery state (T-0105): a push that Gotify could not take is tried again with backoff.
-- The columns belong to the `push` rows; rows made before this migration have no
-- `push_available_at`, so they are never picked up (they were sent at most once).
ALTER TABLE notification
    ADD COLUMN push_attempts INT NOT NULL DEFAULT 0,
    ADD COLUMN push_available_at TIMESTAMPTZ,
    ADD COLUMN pushed_at TIMESTAMPTZ,
    ADD COLUMN push_failed_at TIMESTAMPTZ,
    ADD CONSTRAINT notification_push_attempts_chk CHECK (push_attempts >= 0),
    ADD CONSTRAINT notification_push_state_chk CHECK (pushed_at IS NULL OR push_failed_at IS NULL),
    ADD CONSTRAINT notification_push_channel_chk CHECK (
        channel = 'push'
        OR (push_attempts = 0 AND push_available_at IS NULL
            AND pushed_at IS NULL AND push_failed_at IS NULL)
    );

CREATE INDEX notification_push_due_idx
    ON notification (push_available_at)
    WHERE channel = 'push' AND pushed_at IS NULL AND push_failed_at IS NULL;
