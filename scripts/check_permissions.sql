-- Check current permissions and policies for activity_logs table

-- Check table permissions
SELECT grantee, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
AND table_name = 'activity_logs'
AND grantee IN ('anon', 'authenticated') 
ORDER BY table_name, grantee;

-- Check RLS policies
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'activity_logs';

-- Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity, forcerowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'activity_logs';