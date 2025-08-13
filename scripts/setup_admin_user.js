#!/usr/bin/env node

/**
 * Setup Admin User Script
 * Creates an admin user for testing purposes
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('🔧 Setting up Admin User...');
console.log('=' .repeat(40));

async function createAdminUser() {
  try {
    console.log('\n👤 Creating admin user...');
    
    // Create admin user
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: 'admin@iqralibrary.com',
      password: 'admin123',
      email_confirm: true,
      user_metadata: {
        role: 'admin',
        name: 'Admin User'
      }
    });
    
    if (authError) {
      if (authError.message.includes('already registered')) {
        console.log('✅ Admin user already exists');
        
        // Try to sign in to verify credentials
        const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
          email: 'admin@iqralibrary.com',
          password: 'admin123'
        });
        
        if (signInError) {
          console.log('❌ Admin user exists but credentials are incorrect');
          console.log('🔄 Updating admin user password...');
          
          // Update password
          const { data: updateData, error: updateError } = await supabase.auth.admin.updateUserById(
            authData?.user?.id || 'admin-user-id',
            {
              password: 'admin123'
            }
          );
          
          if (updateError) {
            console.log(`❌ Failed to update password: ${updateError.message}`);
          } else {
            console.log('✅ Admin password updated successfully');
          }
        } else {
          console.log('✅ Admin user credentials verified');
          await supabase.auth.signOut();
        }
      } else {
        console.log(`❌ Failed to create admin user: ${authError.message}`);
        return false;
      }
    } else {
      console.log('✅ Admin user created successfully');
      console.log(`   Email: admin@iqralibrary.com`);
      console.log(`   Password: admin123`);
      console.log(`   User ID: ${authData.user.id}`);
    }
    
    return true;
  } catch (error) {
    console.error('❌ Exception creating admin user:', error.message);
    return false;
  }
}

async function verifyAdminAccess() {
  try {
    console.log('\n🔐 Verifying admin access...');
    
    // Test sign in
    const { data, error } = await supabase.auth.signInWithPassword({
      email: 'admin@iqralibrary.com',
      password: 'admin123'
    });
    
    if (error) {
      console.log(`❌ Admin sign in failed: ${error.message}`);
      return false;
    }
    
    console.log('✅ Admin sign in successful');
    console.log(`   User ID: ${data.user.id}`);
    console.log(`   Email: ${data.user.email}`);
    
    // Test database access
    const { data: studentsData, error: studentsError } = await supabase
      .from('students')
      .select('count(*)')
      .limit(1);
    
    if (studentsError) {
      console.log(`❌ Database access failed: ${studentsError.message}`);
    } else {
      console.log('✅ Database access verified');
    }
    
    // Sign out
    await supabase.auth.signOut();
    console.log('✅ Admin setup completed successfully');
    
    return true;
  } catch (error) {
    console.error('❌ Exception verifying admin access:', error.message);
    return false;
  }
}

async function setupAdmin() {
  try {
    const created = await createAdminUser();
    if (created) {
      const verified = await verifyAdminAccess();
      if (verified) {
        console.log('\n🎉 Admin user setup completed successfully!');
        console.log('\n📋 Admin Credentials:');
        console.log('   Email: admin@iqralibrary.com');
        console.log('   Password: admin123');
        console.log('\n✅ You can now run the admin features test');
      }
    }
  } catch (error) {
    console.error('\n❌ Setup failed:', error.message);
    console.error(error.stack);
  }
}

// Run the setup
setupAdmin().catch(console.error);