-- Schema Improvements Migration
-- Created: 2025-12-13
-- Purpose: Fix critical schema issues identified in analysis

-- ============================================================
-- 1. FIX CURRENCY TYPE: REAL → NUMERIC(10,2)
-- ============================================================
-- This prevents floating-point precision errors in financial calculations

-- Fix subscriptions.amount
ALTER TABLE subscriptions 
  ALTER COLUMN amount TYPE NUMERIC(10,2) USING amount::NUMERIC(10,2);

-- Fix students.subscription_amount (legacy column)
ALTER TABLE students 
  ALTER COLUMN subscription_amount TYPE NUMERIC(10,2) USING subscription_amount::NUMERIC(10,2);

-- Update default constraint
ALTER TABLE subscriptions 
  ALTER COLUMN amount SET DEFAULT 0.00;

-- ============================================================
-- 2. ADD ON DELETE CASCADE FOR FOREIGN KEY
-- ============================================================
-- Prevents orphaned subscriptions when a student is deleted

ALTER TABLE subscriptions 
  DROP CONSTRAINT IF EXISTS subscriptions_student_id_fkey;

ALTER TABLE subscriptions 
  ADD CONSTRAINT subscriptions_student_id_fkey 
    FOREIGN KEY (student_id) 
    REFERENCES students(id) 
    ON DELETE CASCADE;

-- ============================================================
-- 3. ADD MISSING COMPOSITE INDEX FOR PERFORMANCE
-- ============================================================
-- Optimizes common query: find active subscriptions for a student

CREATE INDEX IF NOT EXISTS idx_subscriptions_active_lookup 
  ON subscriptions (student_id, status, end_date);

-- ============================================================
-- 4. ADD is_deleted COLUMN TO SUBSCRIPTIONS (for consistency)
-- ============================================================
-- Matches the soft delete pattern used in students table

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'subscriptions' AND column_name = 'is_deleted'
  ) THEN
    ALTER TABLE subscriptions ADD COLUMN is_deleted boolean DEFAULT false;
  END IF;
END $$;

-- Add index for soft delete queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_is_deleted 
  ON subscriptions (is_deleted) WHERE is_deleted = false;

-- ============================================================
-- 5. ADD MISSING INDEX ON activity_logs.user_id
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_activity_logs_user 
  ON activity_logs (user_id);

-- ============================================================
-- 6. MAKE end_date NOT NULL (with default handling)
-- ============================================================
-- First, update any NULL values to a far-future date

UPDATE subscriptions 
SET end_date = start_date + INTERVAL '30 days'
WHERE end_date IS NULL;

-- Now make it NOT NULL
ALTER TABLE subscriptions 
  ALTER COLUMN end_date SET NOT NULL;

-- ============================================================
-- VERIFICATION QUERY
-- ============================================================
-- Run this to verify the changes:
-- SELECT 
--   column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'subscriptions'
-- ORDER BY ordinal_position;
