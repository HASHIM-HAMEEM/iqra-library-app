-- Create app_settings table for storing application configuration
CREATE TABLE IF NOT EXISTS public.app_settings (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    key TEXT NOT NULL UNIQUE,
    value TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT app_settings_key_check CHECK (length(trim(key)) > 0)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_settings_key ON public.app_settings(key);

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for app_settings
CREATE POLICY "Allow authenticated users to read app_settings" ON public.app_settings
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to insert app_settings" ON public.app_settings
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update app_settings" ON public.app_settings
    FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to delete app_settings" ON public.app_settings
    FOR DELETE TO authenticated USING (true);

-- Grant permissions to authenticated role
GRANT ALL PRIVILEGES ON public.app_settings TO authenticated;
GRANT SELECT ON public.app_settings TO anon;

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON public.app_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default settings
INSERT INTO public.app_settings (key, value, description) VALUES
    ('session_timeout_minutes', '30', 'Session timeout in minutes'),
    ('theme_mode', 'system', 'Application theme mode (light, dark, system)'),
    ('enable_biometric_auth', 'true', 'Enable biometric authentication'),
    ('enable_auto_backup', 'true', 'Enable automatic backups'),
    ('max_failed_attempts', '5', 'Maximum failed authentication attempts before lockout')
ON CONFLICT (key) DO NOTHING