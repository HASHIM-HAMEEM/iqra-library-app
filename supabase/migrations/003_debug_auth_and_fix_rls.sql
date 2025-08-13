-- Fix RLS policies for students table
-- Ensure authenticated users can perform all operations

-- Drop existing policies to recreate them properly
DROP POLICY IF EXISTS "Allow authenticated users to view students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to insert students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to update students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to delete students" ON students;

-- Ensure RLS is enabled
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Create comprehensive RLS policies for authenticated users
CREATE POLICY "authenticated_users_select_students" ON students
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_users_insert_students" ON students
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "authenticated_users_update_students" ON students
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_users_delete_students" ON students
    FOR DELETE TO authenticated USING (true);

-- Grant explicit permissions to authenticated role
GRANT ALL PRIVILEGES ON students TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant read access to anon role
GRANT SELECT ON students TO anon;

-- Create a simple function to test authentication context
CREATE OR REPLACE FUNCTION get_current_user_info()
RETURNS JSON AS $$
BEGIN
    RETURN json_build_object(
        'role', current_user,
        'user_id', auth.uid(),
        'is_authenticated', auth.uid() IS NOT NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the test function
GRANT EXECUTE ON FUNCTION get_current_user_info() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_user_info() TO anon;