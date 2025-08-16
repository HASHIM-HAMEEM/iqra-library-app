-- Fix RLS policies and permissions for all tables

-- Grant basic permissions to anon and authenticated roles
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users full access" ON students;
DROP POLICY IF EXISTS "Allow authenticated users full access" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users full access" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users full access" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users full access" ON app_settings;

DROP POLICY IF EXISTS "Allow anon read access" ON students;
DROP POLICY IF EXISTS "Allow anon read access" ON subscriptions;
DROP POLICY IF EXISTS "Allow anon read access" ON activity_logs;
DROP POLICY IF EXISTS "Allow anon read access" ON sync_metadata;
DROP POLICY IF EXISTS "Allow anon read access" ON app_settings;

-- Create new policies for students table
CREATE POLICY "Allow authenticated users full access" ON students
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow anon read access" ON students
    FOR SELECT USING (auth.role() = 'anon');

-- Create new policies for subscriptions table
CREATE POLICY "Allow authenticated users full access" ON subscriptions
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow anon read access" ON subscriptions
    FOR SELECT USING (auth.role() = 'anon');

-- Create new policies for activity_logs table
CREATE POLICY "Allow authenticated users full access" ON activity_logs
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow anon read access" ON activity_logs
    FOR SELECT USING (auth.role() = 'anon');

-- Create new policies for sync_metadata table
CREATE POLICY "Allow authenticated users full access" ON sync_metadata
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow anon read access" ON sync_metadata
    FOR SELECT USING (auth.role() = 'anon');

-- Create new policies for app_settings table
CREATE POLICY "Allow authenticated users full access" ON app_settings
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow anon read access" ON app_settings
    FOR SELECT USING (auth.role() = 'anon');

-- Ensure RLS is enabled on all tables
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;