-- Baseline schema for notifications-service. Domain tables arrive in later phases.
CREATE TABLE schema_baseline (
    id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    service_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO schema_baseline (service_name) VALUES ('notifications-service');
