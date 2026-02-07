-- Migration 001: Enable required PostgreSQL extensions
-- TimescaleDB for time-series threat event data
-- uuid-ossp for UUID generation

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "timescaledb" CASCADE;
