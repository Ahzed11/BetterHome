-- ADR 0027: push is delivered through Gotify. A push target is the user's own Gotify application
-- token (Gotify routes a message to the owner of the application token), one per user.
CREATE TABLE push_target (
    user_id     UUID PRIMARY KEY,
    token       TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL,
    CONSTRAINT push_target_token_chk CHECK (token ~ '^[A-Za-z0-9._~-]{1,128}$')
);
