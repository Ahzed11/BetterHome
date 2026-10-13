-- Phase 2 task domain (spec §3, §6.2). Recurrence scheduler arrives in Phase 4.

CREATE TABLE rotation (
    id                      UUID PRIMARY KEY,
    household_id            UUID NOT NULL,
    name                    TEXT,
    last_assigned_user_id   UUID,
    created_at              TIMESTAMPTZ NOT NULL
);

CREATE INDEX rotation_household_idx ON rotation (household_id);

CREATE TABLE task_template (
    id                              UUID PRIMARY KEY,
    household_id                    UUID NOT NULL,
    title                           TEXT NOT NULL,
    emoji                           TEXT,
    description                     TEXT NOT NULL DEFAULT '',
    points                          INT NOT NULL,
    late_points                     INT NOT NULL,
    default_due_offset_minutes      INT NOT NULL DEFAULT 1440,
    rotation_id                     UUID NOT NULL REFERENCES rotation (id),
    created_by                      UUID NOT NULL,
    created_at                      TIMESTAMPTZ NOT NULL,
    updated_at                      TIMESTAMPTZ NOT NULL,
    archived_at                     TIMESTAMPTZ,
    CONSTRAINT task_template_title_chk CHECK (char_length(trim(title)) > 0),
    CONSTRAINT task_template_points_chk CHECK (points >= 0),
    CONSTRAINT task_template_late_points_chk CHECK (late_points >= 0),
    CONSTRAINT task_template_due_offset_chk CHECK (default_due_offset_minutes >= 0)
);

CREATE INDEX task_template_household_idx
    ON task_template (household_id)
    WHERE archived_at IS NULL;

CREATE TABLE task (
    id                      UUID PRIMARY KEY,
    household_id            UUID NOT NULL,
    template_id             UUID NOT NULL REFERENCES task_template (id),
    origin                  TEXT NOT NULL,
    title                   TEXT NOT NULL,
    emoji                   TEXT,
    description             TEXT NOT NULL DEFAULT '',
    points                  INT NOT NULL,
    late_points             INT NOT NULL,
    status                  TEXT NOT NULL,
    assignee_id             UUID NOT NULL,
    completer_id            UUID,
    dismissed_by            UUID,
    dismissal_reason        TEXT,
    due_at                  TIMESTAMPTZ,
    due_reminder_sent_at    TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,
    points_awarded          INT,
    created_at              TIMESTAMPTZ NOT NULL,
    updated_at              TIMESTAMPTZ NOT NULL,
    CONSTRAINT task_origin_chk CHECK (origin IN ('manual', 'ad_hoc', 'recurrence')),
    CONSTRAINT task_status_chk CHECK (status IN ('open', 'done', 'dismissed', 'reverted')),
    CONSTRAINT task_dismissal_reason_chk CHECK (
        dismissal_reason IS NULL
        OR dismissal_reason IN ('manual', 'superseded', 'nobody_available', 'reverted_overdue')
    ),
    CONSTRAINT task_points_chk CHECK (points >= 0 AND late_points >= 0),
    CONSTRAINT task_done_integrity_chk CHECK (
        (status = 'done' AND completed_at IS NOT NULL AND points_awarded IS NOT NULL)
        OR (status <> 'done' AND completed_at IS NULL AND points_awarded IS NULL)
    ),
    CONSTRAINT task_dismissed_integrity_chk CHECK (
        (status = 'dismissed' AND dismissal_reason IS NOT NULL AND dismissed_by IS NOT NULL)
        OR (status <> 'dismissed' AND dismissal_reason IS NULL AND dismissed_by IS NULL)
    )
);

CREATE INDEX task_household_status_idx ON task (household_id, status);
CREATE INDEX task_assignee_open_idx ON task (assignee_id) WHERE status = 'open';
