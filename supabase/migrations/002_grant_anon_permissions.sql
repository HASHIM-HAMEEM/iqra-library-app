-- Grant INSERT permissions to anon role for activity_logs table
-- This is needed for testing the logging system connection

-- Grant INSERT permission to anon role for activity_logs
GRANT INSERT ON activity_logs TO anon;

-- Create a policy to allow anon users to insert activity logs
CREATE POLICY "Allow anon users to insert activity_logs" ON activity_logs
    FOR INSERT TO anon WITH CHECK (true);

-- Also grant INSERT permissions for other tables that might be needed for testing
GRANT INSERT ON students TO anon;
GRANT INSERT ON subscriptions TO anon;
GRANT INSERT ON sync_metadata TO anon;

-- Create policies to allow anon users to insert into other tables
CREATE POLICY "Allow anon users to insert students" ON students
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow anon users to insert subscriptions" ON subscriptions
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow anon users to insert sync_metadata" ON sync_metadata
    FOR INSERT TO anon WITH CHECK (true);