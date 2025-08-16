-- Fix RLS policies for students table
-- Drop existing policies first
DROP POLICY IF EXISTS "students_select_policy" ON students;
DROP POLICY IF EXISTS "students_insert_policy" ON students;
DROP POLICY IF EXISTS "students_update_policy" ON students;
DROP POLICY IF EXISTS "students_delete_policy" ON students;

-- Create new comprehensive RLS policies
-- Allow SELECT for both authenticated and anonymous users
CREATE POLICY "students_select_policy" ON students
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Allow INSERT for authenticated users only
CREATE POLICY "students_insert_policy" ON students
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Allow UPDATE for authenticated users only
CREATE POLICY "students_update_policy" ON students
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow DELETE for authenticated users only
CREATE POLICY "students_delete_policy" ON students
    FOR DELETE
    TO authenticated
    USING (true);

-- Ensure proper permissions are granted
GRANT SELECT ON students TO anon;
GRANT ALL PRIVILEGES ON students TO authenticated;

-- Also fix other tables
-- Subscriptions table
DROP POLICY IF EXISTS "subscriptions_select_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_insert_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_update_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_delete_policy" ON subscriptions;

CREATE POLICY "subscriptions_select_policy" ON subscriptions
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "subscriptions_insert_policy" ON subscriptions
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "subscriptions_update_policy" ON subscriptions
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "subscriptions_delete_policy" ON subscriptions
    FOR DELETE
    TO authenticated
    USING (true);

GRANT SELECT ON subscriptions TO anon;
GRANT ALL PRIVILEGES ON subscriptions TO authenticated;

-- Activity logs table
DROP POLICY IF EXISTS "activity_logs_select_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_insert_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_update_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_delete_policy" ON activity_logs;

CREATE POLICY "activity_logs_select_policy" ON activity_logs
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "activity_logs_insert_policy" ON activity_logs
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "activity_logs_update_policy" ON activity_logs
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "activity_logs_delete_policy" ON activity_logs
    FOR DELETE
    TO authenticated
    USING (true);

GRANT SELECT ON activity_logs TO anon;
GRANT ALL PRIVILEGES ON activity_logs TO authenticated;

-- Sync metadata table
DROP POLICY IF EXISTS "sync_metadata_select_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_insert_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_update_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_delete_policy" ON sync_metadata;

CREATE POLICY "sync_metadata_select_policy" ON sync_metadata
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "sync_metadata_insert_policy" ON sync_metadata
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "sync_metadata_update_policy" ON sync_metadata
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "sync_metadata_delete_policy" ON sync_metadata
    FOR DELETE
    TO authenticated
    USING (true);

GRANT SELECT ON sync_metadata TO anon;
GRANT ALL PRIVILEGES ON sync_metadata TO authenticated;