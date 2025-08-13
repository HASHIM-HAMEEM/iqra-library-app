-- Create initial schema for Iqra Library App
-- This migration creates the students, subscriptions, and activity_logs tables
-- with proper constraints, indexes, and RLS policies

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create students table
CREATE TABLE IF NOT EXISTS students (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL CHECK (LENGTH(TRIM(first_name)) > 0),
    last_name TEXT NOT NULL CHECK (LENGTH(TRIM(last_name)) > 0),
    seat_number TEXT,
    date_of_birth TIMESTAMPTZ NOT NULL,
    email TEXT UNIQUE NOT NULL CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    phone TEXT CHECK (phone IS NULL OR LENGTH(phone) >= 10),
    address TEXT,
    subscription_plan TEXT,
    subscription_start_date TIMESTAMPTZ,
    subscription_end_date TIMESTAMPTZ,
    subscription_amount REAL,
    subscription_status TEXT,
    profile_image_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- Additional constraints
    CONSTRAINT valid_name_length CHECK (LENGTH(first_name) <= 50 AND LENGTH(last_name) <= 50),
    CONSTRAINT valid_phone_length CHECK (phone IS NULL OR LENGTH(phone) <= 20),
    CONSTRAINT valid_address_length CHECK (address IS NULL OR LENGTH(address) <= 200)
);

-- Create subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    plan_name TEXT NOT NULL CHECK (LENGTH(TRIM(plan_name)) > 0 AND LENGTH(plan_name) <= 100),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    amount REAL DEFAULT 0 CHECK (amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'cancelled', 'pending')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Date validation
    CONSTRAINT valid_date_range CHECK (end_date IS NULL OR end_date > start_date)
);

-- Create activity_logs table
CREATE TABLE IF NOT EXISTS activity_logs (
    id TEXT PRIMARY KEY,
    action TEXT NOT NULL CHECK (LENGTH(TRIM(action)) > 0 AND LENGTH(action) <= 100),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('student', 'subscription', 'backup', 'settings', 'auth', 'system')),
    entity_id TEXT,
    details TEXT, -- JSON format for additional context
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    user_id TEXT
);

-- Create sync_metadata table for tracking synchronization
CREATE TABLE IF NOT EXISTS sync_metadata (
    user_id TEXT PRIMARY KEY,
    last_sync TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_students_email ON students(email);
CREATE INDEX IF NOT EXISTS idx_students_created_at ON students(created_at);
CREATE INDEX IF NOT EXISTS idx_students_is_deleted ON students(is_deleted);
CREATE INDEX IF NOT EXISTS idx_students_seat_number ON students(seat_number) WHERE seat_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_subscriptions_student_id ON subscriptions(student_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_start_date ON subscriptions(start_date);
CREATE INDEX IF NOT EXISTS idx_subscriptions_end_date ON subscriptions(end_date);
CREATE INDEX IF NOT EXISTS idx_subscriptions_created_at ON subscriptions(created_at);

CREATE INDEX IF NOT EXISTS idx_activity_logs_entity_type ON activity_logs(entity_type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity_id ON activity_logs(entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON activity_logs(action);

CREATE INDEX IF NOT EXISTS idx_sync_metadata_user_id ON sync_metadata(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_metadata_last_sync ON sync_metadata(last_sync);

-- Enable Row Level Security (RLS)
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for authenticated users
-- Students policies
CREATE POLICY "Allow authenticated users to view students" ON students
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert students" ON students
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update students" ON students
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete students" ON students
    FOR DELETE TO authenticated USING (true);

-- Subscriptions policies
CREATE POLICY "Allow authenticated users to view subscriptions" ON subscriptions
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert subscriptions" ON subscriptions
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update subscriptions" ON subscriptions
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete subscriptions" ON subscriptions
    FOR DELETE TO authenticated USING (true);

-- Activity logs policies
CREATE POLICY "Allow authenticated users to view activity_logs" ON activity_logs
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert activity_logs" ON activity_logs
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update activity_logs" ON activity_logs
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete activity_logs" ON activity_logs
    FOR DELETE TO authenticated USING (true);

-- Sync metadata policies
CREATE POLICY "Allow authenticated users to view sync_metadata" ON sync_metadata
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert sync_metadata" ON sync_metadata
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update sync_metadata" ON sync_metadata
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete sync_metadata" ON sync_metadata
    FOR DELETE TO authenticated USING (true);

-- Grant permissions to anon and authenticated roles
GRANT ALL PRIVILEGES ON students TO authenticated;
GRANT ALL PRIVILEGES ON subscriptions TO authenticated;
GRANT ALL PRIVILEGES ON activity_logs TO authenticated;
GRANT ALL PRIVILEGES ON sync_metadata TO authenticated;

GRANT SELECT ON students TO anon;
GRANT SELECT ON subscriptions TO anon;
GRANT SELECT ON activity_logs TO anon;
GRANT SELECT ON sync_metadata TO anon;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON students
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sync_metadata_updated_at BEFORE UPDATE ON sync_metadata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create a function to get subscription statistics
CREATE OR REPLACE FUNCTION get_subscription_stats()
RETURNS TABLE(
    total_subscriptions BIGINT,
    active_subscriptions BIGINT,
    expired_subscriptions BIGINT,
    total_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_subscriptions,
        COUNT(*) FILTER (WHERE status = 'active') as active_subscriptions,
        COUNT(*) FILTER (WHERE status = 'expired') as expired_subscriptions,
        COALESCE(SUM(amount), 0) as total_revenue
    FROM subscriptions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION get_subscription_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_stats() TO anon;

COMMIT;