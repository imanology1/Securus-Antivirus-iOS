-- Migration 005: Create subscriptions table
-- Tracks developer subscription plans and usage limits

CREATE TYPE subscription_plan AS ENUM ('free', 'pro', 'enterprise');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired', 'trial');

CREATE TABLE IF NOT EXISTS subscriptions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    developer_id    UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    plan            subscription_plan NOT NULL DEFAULT 'free',
    status          subscription_status NOT NULL DEFAULT 'active',
    events_limit    INTEGER NOT NULL DEFAULT 10000,
    starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One active subscription per developer
CREATE UNIQUE INDEX idx_subscriptions_active_developer
    ON subscriptions (developer_id)
    WHERE status = 'active';

CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
