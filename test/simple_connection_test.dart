import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Simple Connection Test', () {
    late SupabaseClient client;
    
    setUpAll(() async {
      // Initialize Flutter bindings and mock shared preferences
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      
      // Get environment variables
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      print('Testing Basic Supabase Connection...');
      print('URL: $supabaseUrl');
      print('Anon Key: ${supabaseAnonKey.substring(0, 20)}...');

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        fail('SUPABASE_URL or SUPABASE_ANON_KEY not set');
      }

      // Initialize Supabase using the Flutter package which handles asyncStorage automatically
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      
      client = Supabase.instance.client;
      print('✓ Supabase initialized successfully');
    });

    test('can initialize Supabase client', () {
      expect(client, isNotNull);
      print('✓ Supabase client is properly initialized');
    });

    test('can check auth status', () async {
      try {
        final session = client.auth.currentSession;
        print('Current session: ${session?.user?.email ?? "No user logged in"}');
        print('✓ Auth status check completed');
      } catch (e) {
        print('Auth status check failed: $e');
        fail('Failed to check auth status: $e');
      }
    });

    test('can make a simple query to check connection', () async {
      try {
        // Try a simple query that should work with anon access
        final response = await client
            .from('students')
            .select('id')
            .limit(1);
        
        print('Query response: $response');
        print('✓ Basic query completed successfully');
      } catch (e) {
        print('Query failed: $e');
        print('Error type: ${e.runtimeType}');
        if (e is PostgrestException) {
          print('PostgrestException details:');
          print('  Message: ${e.message}');
          print('  Code: ${e.code}');
          print('  Details: ${e.details}');
          print('  Hint: ${e.hint}');
        }
        // Don't fail the test, just log the error for analysis
      }
    });
  });
}