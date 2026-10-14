-- Number of times the task has been completed. Sent to scoring-service as the idempotency key of
-- the award, so a retried completion cannot award twice and a re-completion after a reversion can.
ALTER TABLE task ADD COLUMN completion_no INT NOT NULL DEFAULT 0;
ALTER TABLE task ADD CONSTRAINT task_completion_no_chk CHECK (completion_no >= 0);
