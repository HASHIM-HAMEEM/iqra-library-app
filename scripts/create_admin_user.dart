import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Script to create a test admin user in Supabase
/// 
/// Usage: dart run scripts/create_admin_user.dart
/// 
/// Environment variables required:
/// - SUPABASE_URL: Your Supabase project URL
/// - SUPABASE_ANON_KEY: Your Supabase anonymous key
void main() async {
  // Get environment variables
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'];
  
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    print('❌ Error: SUPABASE_URL environment variable is not set');
    exit(1);
  }
  
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    print('❌ Error: SUPABASE_ANON_KEY environment variable is not set');
    exit(1);
  }
  
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
    final supabase = Supabase.instance.client;
    
    // Admin user credentials
    const adminEmail = 'scnz141@gmail.com';
    const adminPassword = 'Wehere@25';
    
    print('🔄 Creating admin user: $adminEmail');
    
    // Sign up the admin user
    final response = await supabase.auth.signUp(
      email: adminEmail,
      password: adminPassword,
    );
    
    if (response.user != null) {
      print('✅ Admin user created successfully!');
      print('📧 Email: $adminEmail');
      print('🆔 User ID: ${response.user!.id}');
      print('📅 Created at: ${response.user!.createdAt}');
      
      // Check if email confirmation is required
      if (response.session == null) {
        print('📬 Email confirmation may be required. Check your email inbox.');
      } else {
        print('🎉 User is ready to use (no email confirmation required)');
      }
    } else {
      print('❌ Failed to create admin user');
      if (response.session != null) {
        print('ℹ️  User might already exist');
      }
    }
    
  } catch (e) {
    if (e.toString().contains('User already registered')) {
  
      print('✅ You can use the existing credentials for testing');
    } else {
      print('❌ Error creating admin user: $e');
      exit(1);
    }
  }
  
  print('\n🔧 Next steps:');
  print('1. Update your .env file with TEST_EMAIL=scnz141@gmail.com');
  print('2. Update your .env file with TEST_PASSWORD=Wehere@25');
  print('3. Run integration tests to verify the setup');
}