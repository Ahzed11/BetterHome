-- T-0105: a push row records how its delivery went, so a push Gotify could not take is retried.
-- Only push rows have a state; the inbox rows (in_app) have none.
ALTER TABLE notification
    ADD COLUMN push_state TEXT,
    ADD COLUMN push_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN push_available_at TIMESTAMPTZ;

-- Until now a push row meant "handed to the sender once": those are final.
UPDATE notification SET push_state = 'sent' WHERE channel = 'push';

ALTER TABLE notification
    ADD CONSTRAINT notification_push_state_chk CHECK (
        push_state IN ('pending', 'sent', 'skipped', 'refused', 'gave_up')
    ),
    ADD CONSTRAINT notification_push_state_channel_chk CHECK (
        (channel = 'push') = (push_state IS NOT NULL)
    ),
    ADD CONSTRAINT notification_push_pending_chk CHECK (
        (push_state = 'pending') = (push_available_at IS NOT NULL)
    ),
    ADD CONSTRAINT notification_push_attempts_chk CHECK (push_attempts >= 0);

CREATE INDEX notification_push_due_idx
    ON notification (push_available_at)
    WHERE push_state = 'pending';
