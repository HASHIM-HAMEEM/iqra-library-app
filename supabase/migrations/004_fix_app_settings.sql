-- Fix app_settings table structure
-- Add missing user_id column and proper RLS policies

-- Check if app_settings table exists, if not create it
CREATE TABLE IF NOT EXISTS app_settings (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    key TEXT NOT NULL,
    value TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, key)
);

-- Add user_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'app_settings' AND column_name = 'user_id') THEN
        ALTER TABLE app_settings ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_app_settings_user_id ON app_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_app_settings_key ON app_settings(key);
CREATE INDEX IF NOT EXISTS idx_app_settings_user_key ON app_settings(user_id, key);

-- Enable RLS
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view their own settings" ON app_settings;
DROP POLICY IF EXISTS "Users can insert their own settings" ON app_settings;
DROP POLICY IF EXISTS "Users can update their own settings" ON app_settings;
DROP POLICY IF EXISTS "Users can delete their own settings" ON app_settings;

-- Create RLS policies for app_settings
CREATE POLICY "Users can view their own settings" ON app_settings
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings" ON app_settings
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings" ON app_settings
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own settings" ON app_settings
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL PRIVILEGES ON app_settings TO authenticated;
GRANT SELECT ON app_settings TO anon;

-- Create updated_at trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_app_settings_updated_at') THEN
        CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON app_settings
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;