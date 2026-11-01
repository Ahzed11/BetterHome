-- Contract step of V6 (T-0083): the outbox carries the event type and a payload of short strings,
-- and no running replica writes or reads the rendered title and body any more.

ALTER TABLE notification_outbox
    DROP COLUMN title,
    DROP COLUMN body;
