-- Migration 004: Create threat_events hypertable
-- TimescaleDB hypertable for high-volume, time-series threat event ingestion
-- Receives anonymized threat reports from iOS SDKs

CREATE TYPE threat_type AS ENUM (
    'malware',
    'phishing',
    'network_threat',
    'jailbreak',
    'tampering',
    'man_in_the_middle',
    'suspicious_process',
    'data_exfiltration',
    'unauthorized_access',
    'unknown'
);

CREATE TYPE severity_level AS ENUM (
    'critical',
    'high',
    'medium',
    'low',
    'info'
);

CREATE TABLE IF NOT EXISTS threat_events (
    threat_id       TEXT NOT NULL,
    app_id          UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    threat_type     threat_type NOT NULL,
    severity        severity_level NOT NULL,
    metadata        JSONB NOT NULL DEFAULT '{}',
    app_token       TEXT NOT NULL,
    sdk_version     TEXT NOT NULL,
    os_version      TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Convert to TimescaleDB hypertable for optimized time-series queries
-- chunk_time_interval of 1 day is suitable for threat event volume
SELECT create_hypertable(
    'threat_events',
    'created_at',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);
