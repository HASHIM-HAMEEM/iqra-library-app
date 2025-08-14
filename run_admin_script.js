import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// Supabase configuration
const supabaseUrl = 'https://rqghiwjhizmlvdagicnw.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxZ2hpd2poaXptbHZkYWdpY253Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTAxMTAyNSwiZXhwIjoyMDcwNTg3MDI1fQ.-rKs1y1vCzr4-ZgRW4CLL8LO1DCovM_2V22BhbwmnNs';

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runAdminScript() {
  try {
    console.log('Creating admin user...');
    
    const adminEmail = 'mohsinfarooqi9906@gmail.com';
    const adminPassword = 'Mohsin@iqra#313';
    
    // Use Supabase Auth Admin API to create user
    const { data: user, error: authError } = await supabase.auth.admin.createUser({
      email: adminEmail,
      password: adminPassword,
      email_confirm: true
    });
    
    if (authError) {
      console.error('Error creating user:', authError);
      process.exit(1);
    }
    
    console.log('Admin user created successfully!');
    console.log('User ID:', user.user.id);
    console.log('Email:', user.user.email);
    
    // Create app settings for the user
    const settings = [
      { user_id: user.user.id, key: 'session_timeout_minutes', value: '30', description: 'Session timeout in minutes' },
      { user_id: user.user.id, key: 'theme_mode', value: 'system', description: 'Application theme mode' },
      { user_id: user.user.id, key: 'enable_biometric_auth', value: 'true', description: 'Enable biometric authentication' },
      { user_id: user.user.id, key: 'enable_auto_backup', value: 'true', description: 'Enable automatic backups' },
      { user_id: user.user.id, key: 'max_failed_attempts', value: '5', description: 'Maximum failed authentication attempts' }
    ];
    
    const { error: settingsError } = await supabase
      .from('app_settings')
      .insert(settings);
    
    if (settingsError) {
      console.log('Warning: Could not create app settings:', settingsError.message);
    } else {
      console.log('App settings created successfully!');
    }
    
    // Create sync metadata
    const { error: syncError } = await supabase
      .from('sync_metadata')
      .insert({ user_id: user.user.id, last_sync: new Date().toISOString() });
    
    if (syncError) {
      console.log('Warning: Could not create sync metadata:', syncError.message);
    } else {
      console.log('Sync metadata created successfully!');
    }
    
    console.log('\nAdmin user setup complete!');
    console.log('Email:', adminEmail);
    console.log('Password:', adminPassword);
    console.log('\nIMPORTANT: Please change the password after first login!');
    
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

runAdminScript();