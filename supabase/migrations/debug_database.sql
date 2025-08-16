-- Debug database structure and permissions

-- Check if tables exist
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('students', 'subscriptions', 'activity_logs', 'sync_metadata', 'app_settings');

-- Check table permissions for anon and authenticated roles
SELECT grantee, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
AND grantee IN ('anon', 'authenticated') 
AND table_name IN ('students', 'subscriptions', 'activity_logs', 'sync_metadata', 'app_settings')
ORDER BY table_name, grantee;

-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('students', 'subscriptions', 'activity_logs', 'sync_metadata', 'app_settings')
ORDER BY tablename, policyname;

-- Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('students', 'subscriptions', 'activity_logs', 'sync_metadata', 'app_settings');

-- Test a simple select as anon user (this should work if permissions are correct)
-- Note: This will be executed as the service role, but shows what anon should be able to access
SELECT 'Testing students table' as test_name;
SELECT COUNT(*) as student_count FROM students;

SELECT 'Testing subscriptions table' as test_name;
SELECT COUNT(*) as subscription_count FROM subscriptions;

SELECT 'Testing activity_logs table' as test_name;
SELECT COUNT(*) as activity_log_count FROM activity_logs;

SELECT 'Testing sync_metadata table' as test_name;
SELECT COUNT(*) as sync_metadata_count FROM sync_metadata;

SELECT 'Testing app_settings table' as test_name;
SELECT COUNT(*) as app_settings_count FROM app_settings;