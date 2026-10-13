-- Marking a member away now dismisses their open tasks (reason assignee_away).
ALTER TABLE task DROP CONSTRAINT task_dismissal_reason_chk;
ALTER TABLE task ADD CONSTRAINT task_dismissal_reason_chk CHECK (
    dismissal_reason IS NULL
    OR dismissal_reason IN (
        'manual', 'superseded', 'nobody_available', 'reverted_overdue', 'assignee_away'
    )
);
