-- Reset and fix RLS policies for all tables
-- This migration drops existing policies and recreates them properly

-- Drop existing policies for students table
DROP POLICY IF EXISTS "students_select_policy" ON students;
DROP POLICY IF EXISTS "students_insert_policy" ON students;
DROP POLICY IF EXISTS "students_update_policy" ON students;
DROP POLICY IF EXISTS "students_delete_policy" ON students;
DROP POLICY IF EXISTS "Enable read access for all users" ON students;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON students;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON students;
DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON students;

-- Drop existing policies for subscriptions table
DROP POLICY IF EXISTS "subscriptions_select_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_insert_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_update_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_delete_policy" ON subscriptions;
DROP POLICY IF EXISTS "Enable read access for all users" ON subscriptions;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON subscriptions;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON subscriptions;
DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON subscriptions;

-- Drop existing policies for activity_logs table
DROP POLICY IF EXISTS "activity_logs_select_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_insert_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_update_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_delete_policy" ON activity_logs;
DROP POLICY IF EXISTS "Enable read access for all users" ON activity_logs;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON activity_logs;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON activity_logs;
DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON activity_logs;

-- Drop existing policies for sync_metadata table
DROP POLICY IF EXISTS "sync_metadata_select_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_insert_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_update_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_delete_policy" ON sync_metadata;
DROP POLICY IF EXISTS "Enable read access for all users" ON sync_metadata;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON sync_metadata;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON sync_metadata;
DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON sync_metadata;

-- Drop existing policies for app_settings table
DROP POLICY IF EXISTS "app_settings_select_policy" ON app_settings;
DROP POLICY IF EXISTS "app_settings_insert_policy" ON app_settings;
DROP POLICY IF EXISTS "app_settings_update_policy" ON app_settings;
DROP POLICY IF EXISTS "app_settings_delete_policy" ON app_settings;
DROP POLICY IF EXISTS "Enable read access for all users" ON app_settings;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON app_settings;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON app_settings;
DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON app_settings;

-- Create new comprehensive policies for students table
CREATE POLICY "students_anon_select" ON students FOR SELECT TO anon USING (true);
CREATE POLICY "students_authenticated_select" ON students FOR SELECT TO authenticated USING (true);
CREATE POLICY "students_authenticated_insert" ON students FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "students_authenticated_update" ON students FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "students_authenticated_delete" ON students FOR DELETE TO authenticated USING (true);

-- Create new comprehensive policies for subscriptions table
CREATE POLICY "subscriptions_anon_select" ON subscriptions FOR SELECT TO anon USING (true);
CREATE POLICY "subscriptions_authenticated_select" ON subscriptions FOR SELECT TO authenticated USING (true);
CREATE POLICY "subscriptions_authenticated_insert" ON subscriptions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "subscriptions_authenticated_update" ON subscriptions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "subscriptions_authenticated_delete" ON subscriptions FOR DELETE TO authenticated USING (true);

-- Create new comprehensive policies for activity_logs table
CREATE POLICY "activity_logs_anon_select" ON activity_logs FOR SELECT TO anon USING (true);
CREATE POLICY "activity_logs_authenticated_select" ON activity_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "activity_logs_authenticated_insert" ON activity_logs FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "activity_logs_authenticated_update" ON activity_logs FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "activity_logs_authenticated_delete" ON activity_logs FOR DELETE TO authenticated USING (true);

-- Create new comprehensive policies for sync_metadata table
CREATE POLICY "sync_metadata_anon_select" ON sync_metadata FOR SELECT TO anon USING (true);
CREATE POLICY "sync_metadata_authenticated_select" ON sync_metadata FOR SELECT TO authenticated USING (true);
CREATE POLICY "sync_metadata_authenticated_insert" ON sync_metadata FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "sync_metadata_authenticated_update" ON sync_metadata FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "sync_metadata_authenticated_delete" ON sync_metadata FOR DELETE TO authenticated USING (true);

-- Create new comprehensive policies for app_settings table
CREATE POLICY "app_settings_anon_select" ON app_settings FOR SELECT TO anon USING (true);
CREATE POLICY "app_settings_authenticated_select" ON app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "app_settings_authenticated_insert" ON app_settings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "app_settings_authenticated_update" ON app_settings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "app_settings_authenticated_delete" ON app_settings FOR DELETE TO authenticated USING (true);

-- Grant necessary permissions to anon and authenticated roles
GRANT SELECT ON students TO anon;
GRANT ALL PRIVILEGES ON students TO authenticated;

GRANT SELECT ON subscriptions TO anon;
GRANT ALL PRIVILEGES ON subscriptions TO authenticated;

GRANT SELECT ON activity_logs TO anon;
GRANT ALL PRIVILEGES ON activity_logs TO authenticated;

GRANT SELECT ON sync_metadata TO anon;
GRANT ALL PRIVILEGES ON sync_metadata TO authenticated;

GRANT SELECT ON app_settings TO anon;
GRANT ALL PRIVILEGES ON app_settings TO authenticated;