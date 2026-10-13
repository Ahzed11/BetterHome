-- Phase 4 automation (spec §3.1–3.3 spawning, §5 notifications outbox)

CREATE TABLE task_recurrence (
    id                      UUID PRIMARY KEY,
    household_id            UUID NOT NULL,
    template_id             UUID NOT NULL UNIQUE REFERENCES task_template (id),
    rotation_id             UUID NOT NULL REFERENCES rotation (id),
    rrule                   TEXT NOT NULL,
    assignment_mode         TEXT NOT NULL,
    fixed_assignee_id       UUID,
    timezone                TEXT NOT NULL,
    starts_at               TIMESTAMPTZ NOT NULL,
    ends_at                 TIMESTAMPTZ,
    last_generated_at       TIMESTAMPTZ,
    next_run_at             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL,
    updated_at              TIMESTAMPTZ NOT NULL,
    CONSTRAINT task_recurrence_mode_chk CHECK (
        assignment_mode IN ('fixed', 'round_robin')
    ),
    CONSTRAINT task_recurrence_fixed_chk CHECK (
        (assignment_mode = 'fixed' AND fixed_assignee_id IS NOT NULL)
        OR (assignment_mode = 'round_robin')
    ),
    CONSTRAINT task_recurrence_rrule_chk CHECK (char_length(trim(rrule)) > 0),
    CONSTRAINT task_recurrence_tz_chk CHECK (char_length(trim(timezone)) > 0),
    CONSTRAINT task_recurrence_end_chk CHECK (
        ends_at IS NULL OR ends_at > starts_at
    )
);

CREATE INDEX task_recurrence_due_idx
    ON task_recurrence (next_run_at)
    WHERE next_run_at IS NOT NULL;

CREATE TABLE notification_outbox (
    id              UUID PRIMARY KEY,
    household_id    UUID NOT NULL,
    user_id         UUID NOT NULL,
    type            TEXT NOT NULL,
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    payload_json    TEXT NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL,
    processed_at    TIMESTAMPTZ,
    CONSTRAINT notification_outbox_type_chk CHECK (
        type IN (
            'task_assigned',
            'task_reassigned',
            'due_reminder',
            'overdue',
            'dismissed',
            'superseded',
            'reverted',
            'marked_away',
            'invitation'
        )
    )
);

CREATE INDEX notification_outbox_pending_idx
    ON notification_outbox (created_at)
    WHERE processed_at IS NULL;
