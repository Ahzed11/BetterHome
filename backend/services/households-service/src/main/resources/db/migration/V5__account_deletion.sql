-- Account deletion (spec section 9, T-0032). The local part (profile, memberships) is done in the
-- request's transaction; what other systems must be told is recorded here and retried until every
-- target has confirmed. The row holds no personal data: user_id points at the anonymized profile.
CREATE TABLE account_deletion (
    user_id         UUID PRIMARY KEY REFERENCES app_user (id),
    requested_at    TIMESTAMPTZ NOT NULL,
    attempts        INT NOT NULL DEFAULT 0,
    available_at    TIMESTAMPTZ NOT NULL,
    completed_at    TIMESTAMPTZ,
    CONSTRAINT account_deletion_attempts_chk CHECK (attempts >= 0)
);

CREATE INDEX account_deletion_due_idx
    ON account_deletion (available_at)
    WHERE completed_at IS NULL;

-- One row per target (tasks, scoring, lists, notifications, identity) that confirmed.
CREATE TABLE account_deletion_step (
    user_id     UUID NOT NULL REFERENCES account_deletion (user_id),
    target      TEXT NOT NULL,
    done_at     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (user_id, target),
    CONSTRAINT account_deletion_step_target_chk CHECK (char_length(trim(target)) > 0)
);
