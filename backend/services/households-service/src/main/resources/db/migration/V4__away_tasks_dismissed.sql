-- Marks that the open tasks of the current away period were dismissed, so the scheduler
-- handles each period once. Reset whenever the away period is set again.
ALTER TABLE membership ADD COLUMN away_tasks_dismissed_at TIMESTAMPTZ;

ALTER TABLE membership ADD CONSTRAINT membership_away_dismissed_chk CHECK (
    away_tasks_dismissed_at IS NULL OR away_from IS NOT NULL
);

CREATE INDEX membership_away_due_idx ON membership (away_from)
    WHERE away_from IS NOT NULL AND away_tasks_dismissed_at IS NULL AND left_at IS NULL;
