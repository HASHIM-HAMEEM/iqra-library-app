-- Subscription Audit Fixes Migration
-- Created: 2025-12-13
-- Purpose: Fix subscription status/revenue logic to match app behavior

-- ============================================================
-- 1. UPDATE get_subscription_stats() TO USE CORRECT LOGIC
-- ============================================================
-- Previously counted by status only, now properly excludes cancelled from revenue
-- and counts active as status='active' AND end_date >= NOW()

-- Drop existing function first (required when changing return type)
DROP FUNCTION IF EXISTS get_subscription_stats();

CREATE OR REPLACE FUNCTION get_subscription_stats()
RETURNS TABLE(
    total_subscriptions BIGINT,
    active_subscriptions BIGINT,
    expired_subscriptions BIGINT,
    cancelled_subscriptions BIGINT,
    total_revenue NUMERIC,
    active_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_subscriptions,
        COUNT(*) FILTER (WHERE status = 'active' AND end_date >= NOW()) as active_subscriptions,
        COUNT(*) FILTER (WHERE status = 'expired' OR (status = 'active' AND end_date < NOW())) as expired_subscriptions,
        COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_subscriptions,
        COALESCE(SUM(amount) FILTER (WHERE status != 'cancelled'), 0) as total_revenue,
        COALESCE(SUM(amount) FILTER (WHERE status = 'active' AND end_date >= NOW()), 0) as active_revenue
    FROM subscriptions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. CREATE FUNCTION TO AUTO-EXPIRE SUBSCRIPTIONS
-- ============================================================
-- This can be called periodically (e.g., via pg_cron or app startup)
-- to update status of subscriptions that have passed their end_date

CREATE OR REPLACE FUNCTION expire_past_subscriptions()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE subscriptions
    SET 
        status = 'expired',
        updated_at = NOW()
    WHERE 
        status = 'active' 
        AND end_date < NOW();
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_subscription_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_stats() TO anon;
GRANT EXECUTE ON FUNCTION expire_past_subscriptions() TO authenticated;

-- ============================================================
-- 3. ADD INDEX FOR REVENUE QUERIES (exclude cancelled)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_subscriptions_revenue 
  ON subscriptions (status, created_at, amount) 
  WHERE status != 'cancelled';

-- ============================================================
-- 4. VERIFICATION QUERIES
-- ============================================================
-- Run these to verify the changes:

-- Check active subscriptions (correct logic):
-- SELECT COUNT(*) FROM subscriptions 
-- WHERE status = 'active' AND end_date >= NOW();

-- Check revenue excluding cancelled:
-- SELECT SUM(amount) FROM subscriptions WHERE status != 'cancelled';

-- Test the stats function:
-- SELECT * FROM get_subscription_stats();

-- Test expire function:
-- SELECT expire_past_subscriptions();
