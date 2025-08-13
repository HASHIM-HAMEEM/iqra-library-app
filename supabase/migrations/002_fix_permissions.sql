-- Fix permissions for students table
-- Check current permissions and ensure authenticated users can insert

-- First, check current permissions
SELECT grantee, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
  AND table_name = 'students' 
  AND grantee IN ('anon', 'authenticated') 
ORDER BY table_name, grantee;

-- Grant all necessary permissions to authenticated role
GRANT ALL PRIVILEGES ON students TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant read-only access to anon role
GRANT SELECT ON students TO anon;

-- Ensure RLS policies are properly set
DROP POLICY IF EXISTS "Allow authenticated users to insert students" ON students;
CREATE POLICY "Allow authenticated users to insert students" ON students
    FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated users to view students" ON students;
CREATE POLICY "Allow authenticated users to view students" ON students
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to update students" ON students;
CREATE POLICY "Allow authenticated users to update students" ON students
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated users to delete students" ON students;
CREATE POLICY "Allow authenticated users to delete students" ON students
    FOR DELETE TO authenticated USING (true);

-- Check permissions after fix
SELECT grantee, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
  AND table_name = 'students' 
  AND grantee IN ('anon', 'authenticated') 
ORDER BY table_name, grantee;