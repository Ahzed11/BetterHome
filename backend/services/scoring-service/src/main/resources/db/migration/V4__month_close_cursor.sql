-- Where the monthly close of each household stands (T-0029). One row per household with ledger
-- activity: the next month to close and the instant its local month ends. The close job claims due
-- rows with FOR UPDATE SKIP LOCKED, one household per transaction.
CREATE TABLE month_close_cursor (
    household_id    UUID PRIMARY KEY,
    next_month      CHAR(7) NOT NULL,
    next_close_at   TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    CONSTRAINT month_close_cursor_month_chk CHECK (next_month ~ '^[0-9]{4}-[0-9]{2}$')
);

CREATE INDEX month_close_cursor_due_idx ON month_close_cursor (next_close_at);
