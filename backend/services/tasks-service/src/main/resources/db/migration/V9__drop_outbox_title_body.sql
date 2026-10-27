-- Contract step of the outbox change started in V6 (T-0083): nothing writes or reads the text
-- columns any more, the notification text is rendered by notifications-service from the payload.
ALTER TABLE notification_outbox
    DROP COLUMN title,
    DROP COLUMN body;
