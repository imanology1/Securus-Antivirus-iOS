-- Migration 003: Create apps table
-- Stores registered applications linked to developer accounts

CREATE TYPE app_status AS ENUM ('active', 'inactive', 'suspended');

CREATE TABLE IF NOT EXISTS apps (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    developer_id    UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    api_key         VARCHAR(255) NOT NULL UNIQUE,
    platform        VARCHAR(50) NOT NULL DEFAULT 'ios',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          app_status NOT NULL DEFAULT 'active'
);
