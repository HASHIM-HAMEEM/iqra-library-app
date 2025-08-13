#!/usr/bin/env node

/**
 * Script to create a test admin user in Supabase
 * 
 * Usage: node scripts/create_admin_user.js
 * 
 * Environment variables required:
 * - SUPABASE_URL: Your Supabase project URL
 * - SUPABASE_ANON_KEY: Your Supabase anonymous key
 */

const { createClient } = require('@supabase/supabase-js');

async function createAdminUser() {
  // Get environment variables
  const supabaseUrl = process.env.SUPABASE_URL || 'https://rqghiwjhizmlvdagicnw.supabase.co';
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxZ2hpd2poaXptbHZkYWdpY253Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMTEwMjUsImV4cCI6MjA3MDU4NzAyNX0.zm7SWW-6d_STzZ97L5D-bWdJLmAdgsX_yZV_C7ArjY4';
  
  if (!supabaseUrl) {
    console.error('❌ Error: SUPABASE_URL environment variable is not set');
    process.exit(1);
  }
  
  if (!supabaseAnonKey) {
    console.error('❌ Error: SUPABASE_ANON_KEY environment variable is not set');
    process.exit(1);
  }
  
  try {
    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    
    // Admin user credentials
    const adminEmail = 'scnz141@gmail.com';
    const adminPassword = 'Wehere@25';
    
    console.log('🔄 Creating admin user:', adminEmail);
    
    // Sign up the admin user
    const { data, error } = await supabase.auth.signUp({
      email: adminEmail,
      password: adminPassword,
    });
    
    if (error) {
      if (error.message.includes('User already registered')) {
        console.log('ℹ️  Admin user already exists:', adminEmail);
        console.log('✅ You can use the existing credentials for testing');
        
        // Try to sign in to verify credentials
        const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
          email: adminEmail,
          password: adminPassword,
        });
        
        if (signInError) {
          console.error('❌ Failed to sign in with existing user:', signInError.message);
        } else {
          console.log('✅ Successfully verified existing user credentials');
          console.log('🆔 User ID:', signInData.user.id);
        }
      } else {
        console.error('❌ Error creating admin user:', error.message);
        process.exit(1);
      }
    } else if (data.user) {
      console.log('✅ Admin user created successfully!');
      console.log('📧 Email:', adminEmail);
      console.log('🆔 User ID:', data.user.id);
      console.log('📅 Created at:', data.user.created_at);
      
      // Check if email confirmation is required
      if (!data.session) {
        console.log('📬 Email confirmation may be required. Check your email inbox.');
      } else {
        console.log('🎉 User is ready to use (no email confirmation required)');
      }
    }
    
  } catch (e) {
    console.error('❌ Unexpected error:', e.message);
    process.exit(1);
  }
  
  console.log('\n🔧 Next steps:');
  console.log('1. Update your .env file with TEST_EMAIL=scnz141@gmail.com');
  console.log('2. Update your .env file with TEST_PASSWORD=Wehere@25');
  console.log('3. Run integration tests to verify the setup');
}

// Check if @supabase/supabase-js is available
try {
  require('@supabase/supabase-js');
  createAdminUser();
} catch (e) {
  if (e.code === 'MODULE_NOT_FOUND') {
    console.log('📦 Installing @supabase/supabase-js...');
    const { execSync } = require('child_process');
    try {
      execSync('npm install @supabase/supabase-js', { stdio: 'inherit' });
      console.log('✅ Package installed successfully');
      // Re-run the script
      delete require.cache[require.resolve('@supabase/supabase-js')];
      createAdminUser();
    } catch (installError) {
      console.error('❌ Failed to install @supabase/supabase-js:', installError.message);
      process.exit(1);
    }
  } else {
    throw e;
  }
}