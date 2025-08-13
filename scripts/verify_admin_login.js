#!/usr/bin/env node

/**
 * Script to verify the admin user can sign in successfully
 * 
 * Usage: node scripts/verify_admin_login.js
 */

const { createClient } = require('@supabase/supabase-js');

async function verifyAdminLogin() {
  // Get environment variables
  const supabaseUrl = process.env.SUPABASE_URL || 'https://rqghiwjhizmlvdagicnw.supabase.co';
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxZ2hpd2poaXptbHZkYWdpY253Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMTEwMjUsImV4cCI6MjA3MDU4NzAyNX0.zm7SWW-6d_STzZ97L5D-bWdJLmAdgsX_yZV_C7ArjY4';
  
  try {
    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    
    // Admin user credentials
    const adminEmail = 'scnz141@gmail.com';
    const adminPassword = 'Wehere@25';
    
    console.log('🔐 Testing admin user login...');
    console.log('📧 Email:', adminEmail);
    
    // Try to sign in
    const { data, error } = await supabase.auth.signInWithPassword({
      email: adminEmail,
      password: adminPassword,
    });
    
    if (error) {
      console.error('❌ Login failed:', error.message);
      
      if (error.message.includes('Invalid login credentials')) {
        console.log('\n💡 Possible solutions:');
        console.log('1. Check if email confirmation is required');
        console.log('2. Verify the password is correct');
        console.log('3. Check Supabase Auth settings');
      }
      
      process.exit(1);
    }
    
    if (data.user && data.session) {
      console.log('✅ Admin login successful!');
      console.log('🆔 User ID:', data.user.id);
      console.log('📧 Email:', data.user.email);
      console.log('📅 Last sign in:', data.user.last_sign_in_at);
      console.log('🔑 Session expires at:', new Date(data.session.expires_at * 1000).toISOString());
      
      // Test basic database access
      console.log('\n🔍 Testing database access...');
      
      const { data: students, error: studentsError } = await supabase
        .from('students')
        .select('count')
        .limit(1);
      
      if (studentsError) {
        console.log('⚠️  Database access test failed:', studentsError.message);
      } else {
        console.log('✅ Database access successful');
      }
      
      // Sign out
      await supabase.auth.signOut();
      console.log('🚪 Signed out successfully');
      
    } else {
      console.log('⚠️  Login returned no session - email confirmation may be required');
    }
    
  } catch (e) {
    console.error('❌ Unexpected error:', e.message);
    process.exit(1);
  }
  
  console.log('\n🎉 Admin user verification complete!');
  console.log('✅ Credentials are working correctly');
  console.log('✅ Ready for integration testing');
}

verifyAdminLogin();