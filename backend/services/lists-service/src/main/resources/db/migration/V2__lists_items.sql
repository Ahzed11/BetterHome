-- Lists and items (spec §4, §6.2). household_id is a plain column: households live in another
-- service's database, so there is no cross-service foreign key.

CREATE TABLE list (
    id            UUID PRIMARY KEY,
    household_id  UUID NOT NULL,
    title         TEXT NOT NULL,
    created_by    UUID NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL,
    updated_at    TIMESTAMPTZ NOT NULL,
    archived_at   TIMESTAMPTZ,
    CONSTRAINT list_title_chk CHECK (char_length(trim(title)) > 0)
);

CREATE INDEX list_household_idx ON list (household_id, created_at);

CREATE TABLE item (
    id            UUID PRIMARY KEY,
    list_id       UUID NOT NULL REFERENCES list (id),
    title         TEXT NOT NULL,
    position      INT NOT NULL,
    creator       UUID NOT NULL,
    completer     UUID,
    completed_at  TIMESTAMPTZ,
    deleted_by    UUID,
    deleted_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL,
    updated_at    TIMESTAMPTZ NOT NULL,
    CONSTRAINT item_title_chk CHECK (char_length(trim(title)) > 0),
    CONSTRAINT item_position_chk CHECK (position >= 0),
    CONSTRAINT item_completion_chk CHECK ((completer IS NULL) = (completed_at IS NULL)),
    CONSTRAINT item_deletion_chk CHECK ((deleted_by IS NULL) = (deleted_at IS NULL)),
    CONSTRAINT item_list_position_uq UNIQUE (list_id, position)
);
