-- Phase 3 scoring domain (spec §3.3–3.4, §6.2)

CREATE TABLE point_transaction (
    id              UUID PRIMARY KEY,
    household_id    UUID NOT NULL,
    user_id         UUID NOT NULL,
    task_id         UUID,
    reversion_id    UUID,
    points          INT NOT NULL,
    reason          TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    CONSTRAINT point_transaction_reason_chk CHECK (
        reason IN ('task_completed', 'task_completed_late', 'reversal', 'manual_adjust')
    ),
    CONSTRAINT point_transaction_reversal_link_chk CHECK (
        (reason = 'reversal' AND reversion_id IS NOT NULL)
        OR (reason <> 'reversal')
    )
);

CREATE INDEX point_transaction_household_created_idx
    ON point_transaction (household_id, created_at);

CREATE INDEX point_transaction_household_user_idx
    ON point_transaction (household_id, user_id);

CREATE TABLE task_reversion (
    id                  UUID PRIMARY KEY,
    household_id        UUID NOT NULL,
    task_id             UUID NOT NULL,
    admin_user_id       UUID NOT NULL,
    reason              TEXT NOT NULL,
    points_reversed     INT NOT NULL,
    resulting_status    TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    CONSTRAINT task_reversion_reason_nonempty_chk CHECK (char_length(trim(reason)) > 0),
    CONSTRAINT task_reversion_points_chk CHECK (points_reversed > 0),
    CONSTRAINT task_reversion_status_chk CHECK (
        resulting_status IN ('reverted', 'open', 'dismissed')
    )
);

CREATE INDEX task_reversion_task_idx ON task_reversion (task_id);

ALTER TABLE point_transaction
    ADD CONSTRAINT point_transaction_reversion_fk
    FOREIGN KEY (reversion_id) REFERENCES task_reversion (id);

CREATE TABLE monthly_recap (
    id                  UUID PRIMARY KEY,
    household_id        UUID NOT NULL,
    year_month          CHAR(7) NOT NULL,
    winner_user_id      UUID,
    winner_points       INT NOT NULL DEFAULT 0,
    total_points        INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL,
    CONSTRAINT monthly_recap_ym_chk CHECK (year_month ~ '^[0-9]{4}-[0-9]{2}$'),
    CONSTRAINT monthly_recap_household_ym_uidx UNIQUE (household_id, year_month)
);

CREATE TABLE monthly_recap_celebration (
    recap_id    UUID NOT NULL REFERENCES monthly_recap (id) ON DELETE CASCADE,
    user_id     UUID NOT NULL,
    seen_at     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (recap_id, user_id)
);
