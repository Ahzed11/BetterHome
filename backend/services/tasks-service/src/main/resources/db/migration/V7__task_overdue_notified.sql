-- A task that passes its due date notifies its assignee once (spec §5, T-0081).
ALTER TABLE task ADD COLUMN overdue_notified_at TIMESTAMPTZ;

CREATE INDEX task_overdue_due_idx
    ON task (due_at)
    WHERE status = 'open' AND due_at IS NOT NULL AND overdue_notified_at IS NULL;
