-- Check current permissions for anon and authenticated roles
SELECT 
    grantee, 
    table_name, 
    privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
    AND grantee IN ('anon', 'authenticated') 
ORDER BY table_name, grantee;

-- Check RLS policies for all tables
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Check if RLS is enabled on tables
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Test basic SELECT permissions
SELECT 'Testing students table access' as test;
SELECT COUNT(*) as student_count FROM students;

SELECT 'Testing subscriptions table access' as test;
SELECT COUNT(*) as subscription_count FROM subscriptions;

SELECT 'Testing activity_logs table access' as test;
SELECT COUNT(*) as activity_log_count FROM activity_logs;

SELECT 'Testing sync_metadata table access' as test;
SELECT COUNT(*) as sync_metadata_count FROM sync_metadata;

SELECT 'Testing app_settings table access' as test;
SELECT COUNT(*) as app_settings_count FROM app_settings;