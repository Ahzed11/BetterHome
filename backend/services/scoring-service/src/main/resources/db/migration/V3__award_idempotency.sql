-- Awards are idempotent per task completion: tasks-service numbers each completion of a task
-- (a reverted recurrence task can be completed again) and retries reuse the same number.
ALTER TABLE point_transaction ADD COLUMN completion_no INT;

ALTER TABLE point_transaction
    ADD CONSTRAINT point_transaction_completion_no_chk
    CHECK (completion_no IS NULL OR completion_no > 0);

CREATE UNIQUE INDEX point_transaction_award_uidx
    ON point_transaction (task_id, completion_no)
    WHERE completion_no IS NOT NULL;
