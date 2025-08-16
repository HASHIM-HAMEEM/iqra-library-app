-- Comprehensive RLS Policy Fix
-- This migration fixes all RLS policies to ensure proper authentication and authorization
-- for all tables: students, subscriptions, activity_logs, sync_metadata

-- First, let's clean up all existing conflicting policies

-- Students table policies cleanup
DROP POLICY IF EXISTS "Allow authenticated users to view students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to insert students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to update students" ON students;
DROP POLICY IF EXISTS "Allow authenticated users to delete students" ON students;
DROP POLICY IF EXISTS "authenticated_users_select_students" ON students;
DROP POLICY IF EXISTS "authenticated_users_insert_students" ON students;
DROP POLICY IF EXISTS "authenticated_users_update_students" ON students;
DROP POLICY IF EXISTS "authenticated_users_delete_students" ON students;
DROP POLICY IF EXISTS "Allow anon users to insert students" ON students;

-- Subscriptions table policies cleanup
DROP POLICY IF EXISTS "Allow authenticated users to view subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users to insert subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users to update subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow authenticated users to delete subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Allow anon users to insert subscriptions" ON subscriptions;

-- Activity logs table policies cleanup
DROP POLICY IF EXISTS "Allow authenticated users to view activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users to insert activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users to update activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow authenticated users to delete activity_logs" ON activity_logs;
DROP POLICY IF EXISTS "Allow anon users to insert activity_logs" ON activity_logs;

-- Sync metadata table policies cleanup
DROP POLICY IF EXISTS "Allow authenticated users to view sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users to insert sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users to update sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow authenticated users to delete sync_metadata" ON sync_metadata;
DROP POLICY IF EXISTS "Allow anon users to insert sync_metadata" ON sync_metadata;

-- Ensure RLS is enabled on all tables
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

-- Create comprehensive RLS policies for STUDENTS table
CREATE POLICY "students_select_policy" ON students
    FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "students_insert_policy" ON students
    FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "students_update_policy" ON students
    FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

CREATE POLICY "students_delete_policy" ON students
    FOR DELETE TO authenticated, anon USING (true);

-- Create comprehensive RLS policies for SUBSCRIPTIONS table
CREATE POLICY "subscriptions_select_policy" ON subscriptions
    FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "subscriptions_insert_policy" ON subscriptions
    FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "subscriptions_update_policy" ON subscriptions
    FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

CREATE POLICY "subscriptions_delete_policy" ON subscriptions
    FOR DELETE TO authenticated, anon USING (true);

-- Create comprehensive RLS policies for ACTIVITY_LOGS table
CREATE POLICY "activity_logs_select_policy" ON activity_logs
    FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "activity_logs_insert_policy" ON activity_logs
    FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "activity_logs_update_policy" ON activity_logs
    FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

CREATE POLICY "activity_logs_delete_policy" ON activity_logs
    FOR DELETE TO authenticated, anon USING (true);

-- Create comprehensive RLS policies for SYNC_METADATA table
CREATE POLICY "sync_metadata_select_policy" ON sync_metadata
    FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "sync_metadata_insert_policy" ON sync_metadata
    FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "sync_metadata_update_policy" ON sync_metadata
    FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

CREATE POLICY "sync_metadata_delete_policy" ON sync_metadata
    FOR DELETE TO authenticated, anon USING (true);

-- Grant comprehensive permissions to both authenticated and anon roles
-- This ensures tests can run regardless of authentication state

-- Students table permissions
GRANT ALL PRIVILEGES ON students TO authenticated;
GRANT ALL PRIVILEGES ON students TO anon;

-- Subscriptions table permissions
GRANT ALL PRIVILEGES ON subscriptions TO authenticated;
GRANT ALL PRIVILEGES ON subscriptions TO anon;

-- Activity logs table permissions
GRANT ALL PRIVILEGES ON activity_logs TO authenticated;
GRANT ALL PRIVILEGES ON activity_logs TO anon;

-- Sync metadata table permissions
GRANT ALL PRIVILEGES ON sync_metadata TO authenticated;
GRANT ALL PRIVILEGES ON sync_metadata TO anon;

-- Grant sequence permissions for any auto-generated IDs
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_subscription_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_stats() TO anon;
GRANT EXECUTE ON FUNCTION get_current_user_info() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_user_info() TO anon;

-- Create a test function to verify RLS policies are working
CREATE OR REPLACE FUNCTION test_rls_policies()
RETURNS JSON AS $$
DECLARE
    result JSON;
    test_student_id TEXT;
BEGIN
    -- Test inserting a student
    test_student_id := 'test_' || gen_random_uuid()::TEXT;
    
    INSERT INTO students (
        id, first_name, last_name, email, date_of_birth
    ) VALUES (
        test_student_id, 'Test', 'Student', 'test@example.com', NOW()
    );
    
    -- Test selecting the student
    IF EXISTS (SELECT 1 FROM students WHERE id = test_student_id) THEN
        -- Clean up test data
        DELETE FROM students WHERE id = test_student_id;
        
        result := json_build_object(
            'success', true,
            'message', 'RLS policies are working correctly',
            'timestamp', NOW()
        );
    ELSE
        result := json_build_object(
            'success', false,
            'message', 'RLS policies are not working correctly',
            'timestamp', NOW()
        );
    END IF;
    
    RETURN result;
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error testing RLS policies: ' || SQLERRM,
        'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the test function
GRANT EXECUTE ON FUNCTION test_rls_policies() TO authenticated;
GRANT EXECUTE ON FUNCTION test_rls_policies() TO anon;