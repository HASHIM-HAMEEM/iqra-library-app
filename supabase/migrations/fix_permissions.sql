-- Grant permissions to anon role for basic read access
GRANT SELECT ON students TO anon;
GRANT SELECT ON subscriptions TO anon;
GRANT SELECT ON activity_logs TO anon;
GRANT SELECT ON sync_metadata TO anon;
GRANT SELECT ON app_settings TO anon;

-- Grant full permissions to authenticated role
GRANT ALL PRIVILEGES ON students TO authenticated;
GRANT ALL PRIVILEGES ON subscriptions TO authenticated;
GRANT ALL PRIVILEGES ON activity_logs TO authenticated;
GRANT ALL PRIVILEGES ON sync_metadata TO authenticated;
GRANT ALL PRIVILEGES ON app_settings TO authenticated;

-- Create or replace RLS policies for students table
DROP POLICY IF EXISTS "Allow public read access to students" ON students;
CREATE POLICY "Allow public read access to students" ON students
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow authenticated users full access to students" ON students;
CREATE POLICY "Allow authenticated users full access to students" ON students
    FOR ALL USING (true) WITH CHECK (true);

-- Create or replace RLS policies for subscriptions table
DROP POLICY IF EXISTS "Allow public read access to subscriptions" ON subscriptions;
CREATE POLICY "Allow public read access to subscriptions" ON subscriptions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow authenticated users full access to subscriptions" ON subscriptions;
CREATE POLICY "Allow authenticated users full access to subscriptions" ON subscriptions
    FOR ALL USING (true) WITH CHECK (true);

-- Create or replace RLS policies for activity_logs table
DROP POLICY IF EXISTS "Allow public read access to activity_logs" ON activity_logs;
CREATE POLICY "Allow public read access to activity_logs" ON activity_logs
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow authenticated users full access to activity_logs" ON activity_logs;
CREATE POLICY "Allow authenticated users full access to activity_logs" ON activity_logs
    FOR ALL USING (true) WITH CHECK (true);

-- Create or replace RLS policies for sync_metadata table
DROP POLICY IF EXISTS "Allow public read access to sync_metadata" ON sync_metadata;
CREATE POLICY "Allow public read access to sync_metadata" ON sync_metadata
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow authenticated users full access to sync_metadata" ON sync_metadata;
CREATE POLICY "Allow authenticated users full access to sync_metadata" ON sync_metadata
    FOR ALL USING (true) WITH CHECK (true);

-- Create or replace RLS policies for app_settings table
DROP POLICY IF EXISTS "Allow public read access to app_settings" ON app_settings;
CREATE POLICY "Allow public read access to app_settings" ON app_settings
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow authenticated users full access to app_settings" ON app_settings;
CREATE POLICY "Allow authenticated users full access to app_settings" ON app_settings
    FOR ALL USING (true) WITH CHECK (true);

-- Verify permissions after granting
SELECT 
    'Permissions granted successfully' as status,
    grantee, 
    table_name, 
    privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
    AND grantee IN ('anon', 'authenticated') 
ORDER BY table_name, grantee;