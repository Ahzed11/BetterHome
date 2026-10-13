-- Phase 1 domain schema (spec §2, §6.2)

CREATE TABLE app_user (
    id              UUID PRIMARY KEY,
    auth_subject    UUID NOT NULL UNIQUE,
    email           TEXT NOT NULL,
    given_name      TEXT NOT NULL DEFAULT '',
    family_name     TEXT NOT NULL DEFAULT '',
    language        TEXT NOT NULL DEFAULT 'en',
    timezone        TEXT NOT NULL DEFAULT 'UTC',
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT app_user_language_chk CHECK (language IN ('en', 'fr')),
    CONSTRAINT app_user_email_nonempty_chk CHECK (char_length(trim(email)) > 0)
);

CREATE TABLE household (
    id                      UUID PRIMARY KEY,
    name                    TEXT NOT NULL,
    timezone                TEXT NOT NULL,
    reminder_days_before    INT NOT NULL DEFAULT 0,
    reminder_time           TIME NOT NULL DEFAULT TIME '08:00:00',
    created_by              UUID NOT NULL REFERENCES app_user (id),
    created_at              TIMESTAMPTZ NOT NULL,
    updated_at              TIMESTAMPTZ NOT NULL,
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT household_name_nonempty_chk CHECK (char_length(trim(name)) > 0),
    CONSTRAINT household_reminder_days_chk CHECK (reminder_days_before >= 0)
);

CREATE TABLE membership (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES app_user (id),
    household_id    UUID NOT NULL REFERENCES household (id),
    role            TEXT NOT NULL,
    joined_at       TIMESTAMPTZ NOT NULL,
    left_at         TIMESTAMPTZ,
    away_from       TIMESTAMPTZ,
    away_until      TIMESTAMPTZ,
    away_set_by     UUID REFERENCES app_user (id),
    CONSTRAINT membership_role_chk CHECK (role IN ('admin', 'member')),
    CONSTRAINT membership_away_range_chk CHECK (
        away_until IS NULL OR away_from IS NULL OR away_until >= away_from
    ),
    CONSTRAINT membership_away_set_by_chk CHECK (
        (away_from IS NULL AND away_set_by IS NULL)
        OR (away_from IS NOT NULL AND away_set_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX membership_active_user_household_uidx
    ON membership (user_id, household_id)
    WHERE left_at IS NULL;

CREATE INDEX membership_household_active_idx
    ON membership (household_id)
    WHERE left_at IS NULL;

CREATE TABLE invitation (
    id              UUID PRIMARY KEY,
    household_id    UUID NOT NULL REFERENCES household (id),
    email           TEXT NOT NULL,
    role            TEXT NOT NULL,
    token           TEXT NOT NULL UNIQUE,
    expires_at      TIMESTAMPTZ NOT NULL,
    accepted_at     TIMESTAMPTZ,
    created_by      UUID NOT NULL REFERENCES app_user (id),
    created_at      TIMESTAMPTZ NOT NULL,
    CONSTRAINT invitation_role_chk CHECK (role IN ('admin', 'member')),
    CONSTRAINT invitation_email_nonempty_chk CHECK (char_length(trim(email)) > 0)
);

CREATE INDEX invitation_household_pending_idx
    ON invitation (household_id)
    WHERE accepted_at IS NULL;
