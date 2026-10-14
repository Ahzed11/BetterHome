-- The reason the admin gave when the task was last reverted, so the assignee can read it on the
-- task (spec §3.3, T-0089). The reversion record itself stays in scoring-service.
ALTER TABLE task ADD COLUMN reversion_reason TEXT;
ALTER TABLE task ADD CONSTRAINT task_reversion_reason_chk
    CHECK (reversion_reason IS NULL OR btrim(reversion_reason) <> '');
