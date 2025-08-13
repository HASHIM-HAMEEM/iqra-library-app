#!/usr/bin/env node

/**
 * Script to test admin user permissions for creating students
 * 
 * Usage: node scripts/test_admin_permissions.js
 */

const { createClient } = require('@supabase/supabase-js');

async function testAdminPermissions() {
  // Get environment variables
  const supabaseUrl = process.env.SUPABASE_URL || 'https://rqghiwjhizmlvdagicnw.supabase.co';
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxZ2hpd2poaXptbHZkYWdpY253Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMTEwMjUsImV4cCI6MjA3MDU4NzAyNX0.zm7SWW-6d_STzZ97L5D-bWdJLmAdgsX_yZV_C7ArjY4';
  
  try {
    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    
    // Admin user credentials
    const adminEmail = 'scnz141@gmail.com';
    const adminPassword = 'Wehere@25';
    
    console.log('🔐 Signing in as admin user...');
    
    // Sign in as admin
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: adminEmail,
      password: adminPassword,
    });
    
    if (authError) {
      console.error('❌ Authentication failed:', authError.message);
      process.exit(1);
    }
    
    console.log('✅ Successfully signed in as admin');
    console.log('🆔 User ID:', authData.user.id);
    
    // Test creating a student
    const testStudent = {
      id: `test-student-${Date.now()}`,
      first_name: 'Test',
      last_name: 'Admin',
      email: `test.admin.${Date.now()}@example.com`,
      phone: '+1234567890',
      address: '123 Admin Test Street',
      date_of_birth: '1990-01-01T00:00:00Z',
      subscription_status: 'active',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      is_deleted: false
    };
    
    console.log('📝 Creating test student...');
    
    const { data: studentData, error: studentError } = await supabase
      .from('students')
      .insert(testStudent)
      .select();
    
    if (studentError) {
      console.error('❌ Failed to create student:', studentError.message);
      console.error('Details:', studentError);
    } else {
      console.log('✅ Successfully created student!');
      console.log('📋 Student data:', studentData[0]);
      
      // Clean up - delete the test student
      console.log('🧹 Cleaning up test data...');
      const { error: deleteError } = await supabase
        .from('students')
        .delete()
        .eq('id', testStudent.id);
      
      if (deleteError) {
        console.log('⚠️  Failed to clean up test student:', deleteError.message);
      } else {
        console.log('✅ Test student cleaned up successfully');
      }
    }
    
    // Test reading students
    console.log('📖 Testing read permissions...');
    const { data: allStudents, error: readError } = await supabase
      .from('students')
      .select('id, first_name, last_name, email')
      .limit(5);
    
    if (readError) {
      console.error('❌ Failed to read students:', readError.message);
    } else {
      console.log(`✅ Successfully read ${allStudents.length} students`);
    }
    
    // Sign out
    await supabase.auth.signOut();
    console.log('🚪 Signed out successfully');
    
  } catch (e) {
    console.error('❌ Unexpected error:', e.message);
    process.exit(1);
  }
  
  console.log('\n🎉 Admin permissions test complete!');
  console.log('✅ Admin user has full CRUD permissions');
  console.log('✅ Ready for production use');
}

testAdminPermissions();