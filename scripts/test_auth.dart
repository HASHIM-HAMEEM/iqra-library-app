import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';



void main() async {
  // Get environment variables
  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  final testEmail = const String.fromEnvironment('TEST_EMAIL');
  final testPassword = const String.fromEnvironment('TEST_PASSWORD');

  print('Testing Supabase Authentication...');
  print('URL: $supabaseUrl');
  print('Email: $testEmail');
  print('Password length: ${testPassword.length}');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    print('ERROR: SUPABASE_URL or SUPABASE_ANON_KEY not set');
    exit(1);
  }

  if (testEmail.isEmpty || testPassword.isEmpty) {
    print('ERROR: TEST_EMAIL or TEST_PASSWORD not set');
    exit(1);
  }

  try {
    // Initialize Supabase
    await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
    print('✓ Supabase initialized successfully');

    // Test connection
    try {
      final response = await client.from('students').select('id').limit(1);
      print('✓ Database connection successful');
      print('Sample query result: $response');
    } catch (e) {
      print('✗ Database connection failed: $e');
    }

    // Test authentication
    try {
      final authResponse = await client.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );
      
      if (authResponse.user != null) {
        print('✓ Authentication successful');
        print('User ID: ${authResponse.user!.id}');
        print('User email: ${authResponse.user!.email}');
        
        // Test authenticated query
        try {
          final students = await client.from('students').select('*').limit(5);
          print('✓ Authenticated query successful');
          print('Students found: ${students.length}');
        } catch (e) {
          print('✗ Authenticated query failed: $e');
        }
        
        // Sign out
        await client.auth.signOut();
        print('✓ Sign out successful');
      } else {
        print('✗ Authentication failed: No user returned');
      }
    } catch (e) {
      print('✗ Authentication failed: $e');
      
      // Try to create the user if it doesn't exist
      print('Attempting to create test user...');
      try {
        final signUpResponse = await client.auth.signUp(
          email: testEmail,
          password: testPassword,
        );
        
        if (signUpResponse.user != null) {
          print('✓ Test user created successfully');
          print('User ID: ${signUpResponse.user!.id}');
          print('Please check your email for confirmation if required');
        } else {
          print('✗ Failed to create test user');
        }
      } catch (signUpError) {
        print('✗ Failed to create test user: $signUpError');
      }
    }
    
  } catch (e) {
    print('✗ Supabase initialization failed: $e');
    exit(1);
  }
}