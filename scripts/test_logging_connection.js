import { createClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';

// Supabase configuration
const SUPABASE_URL = 'https://rqghiwjhizmlvdagicnw.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxZ2hpd2poaXptbHZkYWdpY253Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTAxMTAyNSwiZXhwIjoyMDcwNTg3MDI1fQ.-rKs1y1vCzr4-ZgRW4CLL8LO1DCovM_2V22BhbwmnNs';

/**
 * Test script to verify activity logging system connection with database
 */
async function main() {
  console.log('🔍 Testing Activity Logging System Connection...');
  console.log('='.repeat(50));
  
  try {
    // Step 1: Initialize Supabase client
    console.log('\n1. Initializing Supabase connection...');
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    console.log('✅ Supabase client initialized successfully');
    
    // Step 2: Test database connection
    console.log('\n2. Testing database connection...');
    await testDatabaseConnection(supabase);
    console.log('✅ Database connection verified');
    
    // Step 3: Test activity_logs table structure
    console.log('\n3. Verifying activity_logs table structure...');
    await verifyTableStructure(supabase);
    console.log('✅ Table structure verified');
    
    // Step 4: Test activity log creation
    console.log('\n4. Testing activity log creation...');
    const testLogId = await testCreateActivityLog(supabase);
    console.log(`✅ Activity log created successfully (ID: ${testLogId})`);
    
    // Step 5: Test activity log retrieval
    console.log('\n5. Testing activity log retrieval...');
    await testRetrieveActivityLog(supabase, testLogId);
    console.log('✅ Activity log retrieved successfully');
    
    // Step 6: Test activity log queries
    console.log('\n6. Testing activity log queries...');
    await testActivityLogQueries(supabase);
    console.log('✅ Activity log queries working correctly');
    
    // Step 7: Clean up test data
    console.log('\n7. Cleaning up test data...');
    await cleanupTestData(supabase, testLogId);
    console.log('✅ Test data cleaned up');
    
    console.log('\n' + '='.repeat(50));
    console.log('🎉 ALL TESTS PASSED! Logging system is properly connected.');
    console.log('✅ Supabase service: Connected');
    console.log('✅ Database operations: Working');
    console.log('✅ Activity logging: Functional');
    console.log('✅ Table structure: Valid');
    console.log('✅ CRUD operations: Operational');
    
  } catch (error) {
    console.log(`\n❌ TEST FAILED: ${error.message}`);
    console.log('Stack trace:', error.stack);
    process.exit(1);
  }
}

/**
 * Test basic database connection
 */
async function testDatabaseConnection(supabase) {
  try {
    // Try to fetch a simple count from activity_logs table
    const { data, error } = await supabase
      .from('activity_logs')
      .select('id', { count: 'exact', head: true });
    
    if (error) {
      throw new Error(`Database connection failed: ${error.message}`);
    }
    
    console.log('   Database query executed successfully');
  } catch (error) {
    throw new Error(`Database connection failed: ${error.message}`);
  }
}

/**
 * Verify activity_logs table structure
 */
async function verifyTableStructure(supabase) {
  try {
    // Try to select all columns to verify table structure
    const { data, error } = await supabase
      .from('activity_logs')
      .select('id, action, entity_type, entity_id, details, timestamp, user_id')
      .limit(1);
    
    if (error) {
      throw new Error(`Table structure verification failed: ${error.message}`);
    }
    
    console.log('   All required columns exist in activity_logs table');
  } catch (error) {
    throw new Error(`Table structure verification failed: ${error.message}`);
  }
}

/**
 * Test creating an activity log
 */
async function testCreateActivityLog(supabase) {
  const testLog = {
    id: randomUUID(),
    action: 'TEST_CONNECTION',
    entity_type: 'system',
    entity_id: `test-entity-${Date.now()}`,
    details: 'Testing logging system connection from Node.js script',
    timestamp: new Date().toISOString(),
    user_id: null // Test without user for simplicity
  };
  
  const { data, error } = await supabase
    .from('activity_logs')
    .insert([testLog])
    .select()
    .single();
  
  if (error) {
    throw new Error(`Failed to create activity log: ${error.message}`);
  }
  
  if (!data || !data.id) {
    throw new Error('Failed to create activity log - no ID returned');
  }
  
  console.log(`   Created log with details: ${data.details}`);
  return data.id;
}

/**
 * Test retrieving an activity log
 */
async function testRetrieveActivityLog(supabase, logId) {
  const { data, error } = await supabase
    .from('activity_logs')
    .select('*')
    .eq('id', logId)
    .single();
  
  if (error) {
    throw new Error(`Failed to retrieve activity log: ${error.message}`);
  }
  
  if (!data) {
    throw new Error(`Failed to retrieve activity log with ID: ${logId}`);
  }
  
  if (data.action !== 'TEST_CONNECTION') {
    throw new Error('Retrieved log has incorrect data');
  }
  
  console.log(`   Retrieved log: ${data.action} - ${data.details}`);
}

/**
 * Test various activity log queries
 */
async function testActivityLogQueries(supabase) {
  // Test getting recent logs
  const { data: recentLogs, error: recentError } = await supabase
    .from('activity_logs')
    .select('*')
    .order('timestamp', { ascending: false })
    .limit(5);
  
  if (recentError) {
    throw new Error(`Failed to get recent logs: ${recentError.message}`);
  }
  
  console.log(`   Found ${recentLogs.length} recent logs`);
  
  // Test getting logs by type
  const { data: testLogs, error: typeError } = await supabase
    .from('activity_logs')
    .select('*')
    .eq('action', 'TEST_CONNECTION');
  
  if (typeError) {
    throw new Error(`Failed to get logs by type: ${typeError.message}`);
  }
  
  console.log(`   Found ${testLogs.length} TEST_CONNECTION logs`);
  
  if (testLogs.length === 0) {
    throw new Error('Should have found at least one TEST_CONNECTION log');
  }
}

/**
 * Clean up test data
 */
async function cleanupTestData(supabase, logId) {
  try {
    const { error } = await supabase
      .from('activity_logs')
      .delete()
      .eq('id', logId);
    
    if (error) {
      console.log(`   Warning: Could not clean up test data: ${error.message}`);
    } else {
      console.log(`   Removed test log with ID: ${logId}`);
    }
  } catch (error) {
    console.log(`   Warning: Could not clean up test data: ${error.message}`);
    // Don't fail the test for cleanup issues
  }
}

// Run the test
main();