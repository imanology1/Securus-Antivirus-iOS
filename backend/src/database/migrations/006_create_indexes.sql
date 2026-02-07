-- Migration 006: Create performance indexes
-- Optimized for common query patterns in the Securus API

-- Threat events: lookup by app and time range (primary dashboard query)
CREATE INDEX IF NOT EXISTS idx_threat_events_app_id_created_at
    ON threat_events (app_id, created_at DESC);

-- Threat events: filter by type (threat breakdown analytics)
CREATE INDEX IF NOT EXISTS idx_threat_events_threat_type
    ON threat_events (threat_type);

-- Threat events: filter by severity
CREATE INDEX IF NOT EXISTS idx_threat_events_severity
    ON threat_events (severity);

-- Threat events: composite for filtered time queries
CREATE INDEX IF NOT EXISTS idx_threat_events_type_severity_created
    ON threat_events (threat_type, severity, created_at DESC);

-- Apps: API key lookup (every SDK report request)
CREATE INDEX IF NOT EXISTS idx_apps_api_key
    ON apps (api_key);

-- Apps: developer lookup (dashboard app listing)
CREATE INDEX IF NOT EXISTS idx_apps_developer_id
    ON apps (developer_id);

-- Developers: email lookup (authentication)
CREATE INDEX IF NOT EXISTS idx_developers_email
    ON developers (email);
