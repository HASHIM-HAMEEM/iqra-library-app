-- Add sync_metadata table for tracking synchronization
-- This migration adds the missing sync_metadata table

-- Create sync_metadata table for tracking synchronization
CREATE TABLE IF NOT EXISTS sync_metadata (
    user_id TEXT PRIMARY KEY,
    last_sync TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sync_metadata_user_id ON sync_metadata(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_metadata_last_sync ON sync_metadata(last_sync);

-- Enable Row Level Security (RLS)
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for sync_metadata
CREATE POLICY "Allow authenticated users to view sync_metadata" ON sync_metadata
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert sync_metadata" ON sync_metadata
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update sync_metadata" ON sync_metadata
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete sync_metadata" ON sync_metadata
    FOR DELETE TO authenticated USING (true);

-- Grant permissions to anon and authenticated roles
GRANT ALL PRIVILEGES ON sync_metadata TO authenticated;
GRANT SELECT ON sync_metadata TO anon;

-- Create trigger for updated_at
CREATE TRIGGER update_sync_metadata_updated_at BEFORE UPDATE ON sync_metadata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;