-- Check current permissions for students table
SELECT grantee, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
  AND table_name = 'students' 
  AND grantee IN ('anon', 'authenticated') 
ORDER BY table_name, grantee;

-- Grant necessary permissions to anon and authenticated roles
GRANT SELECT ON students TO anon;
GRANT ALL PRIVILEGES ON students TO authenticated;

-- Check RLS policies for students table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'students';

-- Create a permissive RLS policy for anon users to insert students
DROP POLICY IF EXISTS "anon_can_insert_students" ON students;
CREATE POLICY "anon_can_insert_students" 
ON students 
FOR INSERT 
TO anon 
WITH CHECK (true);

-- Create a permissive RLS policy for authenticated users
DROP POLICY IF EXISTS "authenticated_can_manage_students" ON students;
CREATE POLICY "authenticated_can_manage_students" 
ON students 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'students';