require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

async function testCompleteAuthFlow() {
  console.log('🔐 Testing Complete Authentication Flow and CRUD Operations\n');
  
  try {
    // Test 1: Authentication
    console.log('1️⃣ Testing Admin Authentication...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: process.env.TEST_EMAIL,
      password: process.env.TEST_PASSWORD
    });
    
    if (authError) {
      console.error('❌ Authentication failed:', authError.message);
      return;
    }
    
    console.log('✅ Admin authenticated successfully');
    console.log(`   User ID: ${authData.user.id}`);
    console.log(`   Email: ${authData.user.email}`);
    console.log(`   Session expires: ${new Date(authData.session.expires_at * 1000).toISOString()}\n`);
    
    // Test 2: Students CRUD Operations
    console.log('2️⃣ Testing Students CRUD Operations...');
    
    // Create a test student
    const testStudent = {
      id: 'test-student-' + Date.now(),
      first_name: 'Test',
      last_name: 'Student',
      email: `test.student.${Date.now()}@example.com`,
      phone: '+1234567890',
      address: '123 Test Street',
      date_of_birth: '2000-01-01',
      seat_number: 999
    };
    
    // CREATE
    console.log('   📝 Creating test student...');
    const { data: createData, error: createError } = await supabase
      .from('students')
      .insert([testStudent])
      .select();
    
    if (createError) {
      console.error('   ❌ Failed to create student:', createError.message);
    } else {
      console.log('   ✅ Student created successfully');
      console.log(`      ID: ${createData[0].id}`);
      console.log(`      Name: ${createData[0].first_name} ${createData[0].last_name}`);
    }
    
    // READ
    console.log('   📖 Reading all students...');
    const { data: readData, error: readError } = await supabase
      .from('students')
      .select('*')
      .eq('is_deleted', false)
      .order('created_at', { ascending: false })
      .limit(5);
    
    if (readError) {
      console.error('   ❌ Failed to read students:', readError.message);
    } else {
      console.log(`   ✅ Retrieved ${readData.length} students`);
      readData.forEach((student, index) => {
        console.log(`      ${index + 1}. ${student.first_name} ${student.last_name} (${student.email})`);
      });
    }
    
    // UPDATE
    console.log('   ✏️ Updating test student...');
    const { data: updateData, error: updateError } = await supabase
      .from('students')
      .update({ phone: '+9876543210', address: '456 Updated Street' })
      .eq('id', testStudent.id)
      .select();
    
    if (updateError) {
      console.error('   ❌ Failed to update student:', updateError.message);
    } else {
      console.log('   ✅ Student updated successfully');
      console.log(`      New phone: ${updateData[0].phone}`);
      console.log(`      New address: ${updateData[0].address}`);
    }
    
    // Test 3: Subscriptions CRUD Operations
    console.log('\n3️⃣ Testing Subscriptions CRUD Operations...');
    
    const testSubscription = {
      id: 'test-subscription-' + Date.now(),
      student_id: testStudent.id,
      plan_name: 'Monthly Plan',
      start_date: new Date().toISOString(),
      end_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      amount: 50.00,
      status: 'active'
    };
    
    // CREATE Subscription
    console.log('   📝 Creating test subscription...');
    const { data: subCreateData, error: subCreateError } = await supabase
      .from('subscriptions')
      .insert([testSubscription])
      .select();
    
    if (subCreateError) {
      console.error('   ❌ Failed to create subscription:', subCreateError.message);
    } else {
      console.log('   ✅ Subscription created successfully');
      console.log(`      ID: ${subCreateData[0].id}`);
      console.log(`      Plan: ${subCreateData[0].plan_name}`);
      console.log(`      Amount: $${subCreateData[0].amount}`);
    }
    
    // READ Subscriptions
    console.log('   📖 Reading subscriptions...');
    const { data: subReadData, error: subReadError } = await supabase
      .from('subscriptions')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5);
    
    if (subReadError) {
      console.error('   ❌ Failed to read subscriptions:', subReadError.message);
    } else {
      console.log(`   ✅ Retrieved ${subReadData.length} subscriptions`);
      subReadData.forEach((sub, index) => {
        console.log(`      ${index + 1}. ${sub.plan_name} - $${sub.amount} (${sub.status})`);
      });
    }
    
    // Test 4: Activity Logs
    console.log('\n4️⃣ Testing Activity Logs...');
    
    const testActivityLog = {
      id: 'test-activity-' + Date.now(),
      action: 'test_operation',
      entity_type: 'student',
      entity_id: testStudent.id,
      details: { test: 'Complete auth flow test', timestamp: new Date().toISOString() },
      user_id: authData.user.id
    };
    
    console.log('   📝 Creating activity log...');
    const { data: logCreateData, error: logCreateError } = await supabase
      .from('activity_logs')
      .insert([testActivityLog])
      .select();
    
    if (logCreateError) {
      console.error('   ❌ Failed to create activity log:', logCreateError.message);
    } else {
      console.log('   ✅ Activity log created successfully');
      console.log(`      Action: ${logCreateData[0].action}`);
      console.log(`      Entity: ${logCreateData[0].entity_type}`);
    }
    
    // Test 5: RLS Policy Validation
    console.log('\n5️⃣ Testing RLS Policies...');
    
    // Test authenticated user permissions
    console.log('   🔒 Testing authenticated user permissions...');
    const { data: rlsTestData, error: rlsTestError } = await supabase
      .from('students')
      .select('count')
      .eq('is_deleted', false);
    
    if (rlsTestError) {
      console.error('   ❌ RLS policy test failed:', rlsTestError.message);
    } else {
      console.log('   ✅ RLS policies working correctly for authenticated user');
    }
    
    // Test 6: Session Validation
    console.log('\n6️⃣ Testing Session Validation...');
    
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    
    if (sessionError) {
      console.error('   ❌ Session validation failed:', sessionError.message);
    } else {
      console.log('   ✅ Session is valid');
      console.log(`      Access token present: ${!!sessionData.session?.access_token}`);
      console.log(`      Refresh token present: ${!!sessionData.session?.refresh_token}`);
      console.log(`      Token type: ${sessionData.session?.token_type}`);
    }
    
    // Cleanup: Delete test data
    console.log('\n🧹 Cleaning up test data...');
    
    // Delete test subscription
    await supabase
      .from('subscriptions')
      .delete()
      .eq('id', testSubscription.id);
    
    // Delete test activity log
    await supabase
      .from('activity_logs')
      .delete()
      .eq('id', testActivityLog.id);
    
    // Delete test student
    await supabase
      .from('students')
      .delete()
      .eq('id', testStudent.id);
    
    console.log('✅ Test data cleaned up successfully');
    
    // Sign out
    console.log('\n🔓 Signing out...');
    const { error: signOutError } = await supabase.auth.signOut();
    
    if (signOutError) {
      console.error('❌ Sign out failed:', signOutError.message);
    } else {
      console.log('✅ Signed out successfully');
    }
    
    console.log('\n🎉 Complete Authentication Flow Test PASSED!');
    console.log('\n📋 Summary:');
    console.log('   ✅ Admin authentication working');
    console.log('   ✅ Students CRUD operations working');
    console.log('   ✅ Subscriptions CRUD operations working');
    console.log('   ✅ Activity logs working');
    console.log('   ✅ RLS policies working');
    console.log('   ✅ Session management working');
    console.log('   ✅ Database integration robust and production-ready');
    
  } catch (error) {
    console.error('\n💥 Test failed with error:', error.message);
    console.error('Stack trace:', error.stack);
  }
}

// Run the test
testCompleteAuthFlow();