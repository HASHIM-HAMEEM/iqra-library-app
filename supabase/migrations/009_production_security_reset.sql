-- PRODUCTION SECURITY MIGRATION
-- This migration implements strict security policies for production deployment
-- - Revokes all excessive permissions from anon role
-- - Implements proper per-user ownership RLS policies where applicable
-- - Ensures minimal privilege access patterns

-- === REVOKE ALL EXCESSIVE PERMISSIONS ===

-- Revoke ALL PRIVILEGES grants to anon role (major security issue)
REVOKE ALL PRIVILEGES ON students FROM anon;
REVOKE ALL PRIVILEGES ON subscriptions FROM anon;
REVOKE ALL PRIVILEGES ON activity_logs FROM anon;
REVOKE ALL PRIVILEGES ON sync_metadata FROM anon;
REVOKE ALL PRIVILEGES ON app_settings FROM anon;

-- Also revoke dangerous INSERT/UPDATE/DELETE from anon
REVOKE INSERT, UPDATE, DELETE ON students FROM anon;
REVOKE INSERT, UPDATE, DELETE ON subscriptions FROM anon;
REVOKE INSERT, UPDATE, DELETE ON activity_logs FROM anon;
REVOKE INSERT, UPDATE, DELETE ON sync_metadata FROM anon;
REVOKE INSERT, UPDATE, DELETE ON app_settings FROM anon;

-- Revoke SELECT on sensitive data from anon (PII should not be publicly readable)
REVOKE SELECT ON students FROM anon;
REVOKE SELECT ON subscriptions FROM anon;
REVOKE SELECT ON activity_logs FROM anon;
REVOKE SELECT ON sync_metadata FROM anon;
REVOKE SELECT ON app_settings FROM anon;

-- === DROP ALL EXISTING OVERLY PERMISSIVE POLICIES ===

-- Students table policies
DROP POLICY IF EXISTS "Allow authenticated users to view students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to insert students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to update students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to delete students" ON students;
DROP POLICY IF EXISTS "authenticated_users_select_students" ON students;
DROP POLICY IF EXISTS "authenticated_users_insert_students" ON students;
DROP POLICY IF EXISTS "authenticated_users_update_students" ON students;
DROP POLICY IF EXISTS "authenticated_users_delete_students" ON students;
DROP POLICY IF EXISTS "students_select_policy" ON students;
DROP POLICY IF EXISTS "students_insert_policy" ON students;
DROP POLICY IF EXISTS "students_update_policy" ON students;
DROP POLICY IF EXISTS "students_delete_policy" ON students;
DROP POLICY IF EXISTS "Allow public read access to students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users full access to students" ON students;
DROP POLICY IF EXISTS "anon_can_insert_students" ON students;
DROP POLICY IF EXISTS "authenticated_can_manage_students" ON students;
DROP POLICY IF EXISTS "students_anon_select" ON students;
DROP POLICY IF EXISTS "students_authenticated_select" ON students;
DROP POLICY IF EXISTS "students_authenticated_insert" ON students;
DROP POLICY IF EXISTS "students_authenticated_update" ON students;
DROP POLICY IF EXISTS "students_authenticated_delete" ON students;
DROP POLICY IF EXISTS "Allow anon users to insert students" ON students;

-- Subscriptions table policies
DROP POLICY IF EXISTS "Allow authenticated users to view subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users to insert subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users to update subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users to delete subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_select_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_insert_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_update_policy" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_delete_policy" ON subscriptions;
DROP POLICY IF EXISTS "Allow public read access to subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users full access to subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_anon_select" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_authenticated_select" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_authenticated_insert" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_authenticated_update" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_authenticated_delete" ON subscriptions;
DROP POLICY IF EXISTS "Allow anon users to insert subscriptions" ON subscriptions;

-- Activity logs table policies
DROP POLICY IF EXISTS "Allow authenticated users to view activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users to insert activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users to update activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users to delete activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_select_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_insert_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_update_policy" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_delete_policy" ON activity_logs;
DROP POLICY IF EXISTS "Allow public read access to activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users full access to activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_anon_select" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_authenticated_select" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_authenticated_insert" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_authenticated_update" ON activity_logs;
DROP POLICY IF EXISTS "activity_logs_authenticated_delete" ON activity_logs;
DROP POLICY IF EXISTS "Allow anon users to insert activity_logs" ON activity_logs;

-- Sync metadata table policies
DROP POLICY IF EXISTS "Allow authenticated users to view sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users to insert sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users to update sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users to delete sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_select_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_insert_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_update_policy" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_delete_policy" ON sync_metadata;
DROP POLICY IF EXISTS "Allow public read access to sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users full access to sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_anon_select" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_authenticated_select" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_authenticated_insert" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_authenticated_update" ON sync_metadata;
DROP POLICY IF EXISTS "sync_metadata_authenticated_delete" ON sync_metadata;
DROP POLICY IF EXISTS "Allow anon users to insert sync_metadata" ON sync_metadata;

-- App settings policies
DROP POLICY IF EXISTS "Allow authenticated users to read app_settings" ON app_settings;
DROP POLICY IF EXISTS "Allow authenticated users to insert app_settings" ON app_settings;
DROP POLICY IF EXISTS "Allow authenticated users to update app_settings" ON app_settings;
DROP POLICY IF EXISTS "Allow authenticated users to delete app_settings" ON app_settings;
DROP POLICY IF EXISTS "Users can view their own settings" ON app_settings;
DROP POLICY IF EXISTS "Users can insert their own settings" ON app_settings;
DROP POLICY IF EXISTS "Users can update their own settings" ON app_settings;
DROP POLICY IF EXISTS "Users can delete their own settings" ON app_settings;
DROP POLICY IF EXISTS "Allow public read access to app_settings" ON app_settings;
DROP POLICY IF EXISTS "Allow authenticated users full access to app_settings" ON app_settings;
DROP POLICY IF EXISTS "app_settings_anon_select" ON app_settings;
DROP POLICY IF EXISTS "app_settings_authenticated_select" ON app_settings;
DROP POLICY IF EXISTS "app_settings_authenticated_insert" ON app_settings;
DROP POLICY IF EXISTS "app_settings_authenticated_update" ON app_settings;
DROP POLICY IF EXISTS "app_settings_authenticated_delete" ON app_settings;

-- === ENSURE RLS IS ENABLED ON ALL TABLES ===
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- === CREATE STRICT PRODUCTION RLS POLICIES ===

-- APP_SETTINGS: Per-user data (has user_id column for ownership)
CREATE POLICY "app_settings_user_select" ON app_settings
    FOR SELECT TO authenticated 
    USING (auth.uid() = user_id);

CREATE POLICY "app_settings_user_insert" ON app_settings
    FOR INSERT TO authenticated 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "app_settings_user_update" ON app_settings
    FOR UPDATE TO authenticated 
    USING (auth.uid() = user_id) 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "app_settings_user_delete" ON app_settings
    FOR DELETE TO authenticated 
    USING (auth.uid() = user_id);

-- SYNC_METADATA: Per-user data (user_id is primary key)
CREATE POLICY "sync_metadata_user_select" ON sync_metadata
    FOR SELECT TO authenticated 
    USING (auth.uid()::text = user_id);

CREATE POLICY "sync_metadata_user_insert" ON sync_metadata
    FOR INSERT TO authenticated 
    WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "sync_metadata_user_update" ON sync_metadata
    FOR UPDATE TO authenticated 
    USING (auth.uid()::text = user_id) 
    WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "sync_metadata_user_delete" ON sync_metadata
    FOR DELETE TO authenticated 
    USING (auth.uid()::text = user_id);

-- STUDENTS: Library management data - authenticated users can manage all records
-- (This is a library app where authenticated staff need to manage all student records)
CREATE POLICY "students_authenticated_all" ON students
    FOR ALL TO authenticated 
    USING (true) 
    WITH CHECK (true);

-- SUBSCRIPTIONS: Library management data - authenticated users can manage all records
CREATE POLICY "subscriptions_authenticated_all" ON subscriptions
    FOR ALL TO authenticated 
    USING (true) 
    WITH CHECK (true);

-- ACTIVITY_LOGS: Audit data - authenticated users can view and insert, no updates/deletes
CREATE POLICY "activity_logs_authenticated_select" ON activity_logs
    FOR SELECT TO authenticated 
    USING (true);

CREATE POLICY "activity_logs_authenticated_insert" ON activity_logs
    FOR INSERT TO authenticated 
    WITH CHECK (true);

-- === GRANT MINIMAL NECESSARY PERMISSIONS ===

-- Grant only SELECT to authenticated users (operations controlled by RLS policies)
GRANT SELECT, INSERT, UPDATE, DELETE ON students TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON subscriptions TO authenticated;
GRANT SELECT, INSERT ON activity_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON sync_metadata TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_settings TO authenticated;

-- Grant sequence access for ID generation
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- === FUNCTION PERMISSIONS ===

-- Ensure stats and user info functions have minimal access
-- (These were previously granted to anon which is a security risk)
REVOKE EXECUTE ON FUNCTION get_subscription_stats() FROM anon;
REVOKE EXECUTE ON FUNCTION get_current_user_info() FROM anon;
REVOKE EXECUTE ON FUNCTION test_rls_policies() FROM anon;

-- Grant only to authenticated users
GRANT EXECUTE ON FUNCTION get_subscription_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_user_info() TO authenticated;
GRANT EXECUTE ON FUNCTION test_rls_policies() TO authenticated;

-- === CREATE SECURITY VERIFICATION FUNCTION ===

CREATE OR REPLACE FUNCTION verify_production_security()
RETURNS TABLE(
    table_name TEXT,
    rls_enabled BOOLEAN,
    anon_permissions TEXT[],
    authenticated_permissions TEXT[],
    policy_count INTEGER
) 
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.table_name::TEXT,
        c.row_security::BOOLEAN as rls_enabled,
        ARRAY(
            SELECT privilege_type 
            FROM information_schema.table_privileges 
            WHERE table_name = c.table_name 
            AND grantee = 'anon'
        ) as anon_permissions,
        ARRAY(
            SELECT privilege_type 
            FROM information_schema.table_privileges 
            WHERE table_name = c.table_name 
            AND grantee = 'authenticated'
        ) as authenticated_permissions,
        (
            SELECT COUNT(*)::INTEGER 
            FROM pg_policies 
            WHERE tablename = c.table_name
        ) as policy_count
    FROM information_schema.tables c
    WHERE c.table_schema = 'public' 
    AND c.table_type = 'BASE TABLE'
    AND c.table_name IN ('students', 'subscriptions', 'activity_logs', 'sync_metadata', 'app_settings')
    ORDER BY c.table_name;
END;
$$ LANGUAGE plpgsql;

-- Grant execute only to authenticated users
GRANT EXECUTE ON FUNCTION verify_production_security() TO authenticated;

COMMIT;