import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';
import '../test_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for Row Level Security (RLS) policies
/// 
/// These tests verify that RLS policies are working correctly
/// and that users can only access data they're authorized to see.
/// 
/// Environment variables required:
/// - SUPABASE_URL: Your Supabase project URL
/// - SUPABASE_ANON_KEY: Your Supabase anonymous key
/// - TEST_EMAIL: Test user email for authentication
/// - TEST_PASSWORD: Test user password for authentication
void main() {
  integrationTestGroup('RLS Policy Tests', () {
    late SupabaseClient supabaseClient;
    late SupabaseService supabaseService;
    late SupabaseService authenticatedService;
    bool authReady = false;
    
    setUpAll(() async {
      // Initialize Flutter bindings and mock shared preferences for plugin calls in test env
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      
      // Only initialize if environment variables are set
      if (!TestConfig.canRunIntegrationTests) {
        return; // Skip initialization if environment not configured
      }
      
      final client = await TestUtils.initializeSupabaseForTesting();
      if (client != null) {
        supabaseClient = client;
        supabaseService = SupabaseService(client: supabaseClient, enabled: true);
        authenticatedService = SupabaseService(client: supabaseClient, enabled: true);
      }
    });

    group('Anonymous User Access', () {
      setUp(() async {
        // Ensure we're signed out for anonymous tests
        if (!TestConfig.canRunIntegrationTests) return;
        await supabaseService.signOut();
      });

      test('anonymous users can read students table', () async {
        // Anonymous users should be able to read students
        final students = await supabaseService.getAllStudents();
        expect(students, isA<List<Student>>());
      });

      test('anonymous users can read subscriptions table', () async {
        // Anonymous users should be able to read subscriptions
        final subscriptions = await supabaseService.getAllSubscriptions();
        expect(subscriptions, isA<List<Subscription>>());
      });

      test('anonymous users can read activity logs table', () async {
        // Anonymous users should be able to read activity logs
        final logs = await supabaseService.getAllActivityLogs();
        expect(logs, isA<List<ActivityLog>>());
      });

      test('anonymous users cannot create students', () async {
        final testStudent = TestDataFactory.createTestStudent();
        
        // This should fail due to RLS policy
        expect(
          () => supabaseService.createStudent(testStudent),
          throwsA(isA<SupabaseServiceException>()),
        );
      });

      test('anonymous users cannot create subscriptions', () async {
        final testSubscription = TestDataFactory.createTestSubscription();
        
        // This should fail due to RLS policy
        expect(
          () => supabaseService.createSubscription(testSubscription),
          throwsA(isA<SupabaseServiceException>()),
        );
      });

      test('anonymous users cannot create activity logs', () async {
        final testLog = TestDataFactory.createTestActivityLog();
        
        // This should fail due to RLS policy
        expect(
          () => supabaseService.createActivityLog(testLog),
          throwsA(isA<SupabaseServiceException>()),
        );
      });

      test('anonymous users cannot update students', () async {
        final testStudent = TestDataFactory.createTestStudent();
        
        // This should fail due to RLS policy
        expect(
          () => supabaseService.updateStudent(testStudent),
          throwsA(isA<SupabaseServiceException>()),
        );
      });

      test('anonymous users cannot delete students', () async {
        // This should fail due to RLS policy
        expect(
          () => supabaseService.deleteStudent('test-id'),
          throwsA(isA<SupabaseServiceException>()),
        );
      });
    });

    group('Authenticated User Access', () {
      setUp(() async {
        // Sign in for authenticated tests
        authReady = false;
        if (!TestConfig.canRunIntegrationTests) {
          print('Authenticated tests will be skipped: environment not configured');
          return;
        }
        if (TestConfig.canRunAuthTests) {
          try {
            await authenticatedService.signInWithPassword(
              TestConfig.testUserEmail,
              TestConfig.testUserPassword,
            );
          } catch (e) {
            // If sign in fails, mark as not ready and continue; tests will skip
            print('Failed to sign in test user: $e');
          }
        }
        authReady = supabaseClient.auth.currentUser != null;
        if (!authReady) {
          print('Authenticated tests will be skipped: no authenticated session');
        }
      });

      tearDown(() async {
        // Sign out after each test
        if (!TestConfig.canRunIntegrationTests) return;
        try {
          await authenticatedService.signOut();
        } catch (_) {}
      });

      test('authenticated users can create students', () async {
        if (!TestConfig.canRunAuthTests || !authReady) {
          print('Skipping: auth not ready');
          return;
        }
        final testStudent = TestDataFactory.createTestStudent();
        
        await expectLater(
          authenticatedService.createStudent(testStudent),
          completes,
        );
        
        // Clean up
        await authenticatedService.deleteStudent(testStudent.id, hard: true);
      }, skip: false);

      test('authenticated users can update students', () async {
        if (!TestConfig.canRunAuthTests || !authReady) {
          print('Skipping: auth not ready');
          return;
        }
        final testStudent = TestDataFactory.createTestStudent();
        
        // Create student first
        await authenticatedService.createStudent(testStudent);
        
        // Update student
        final updatedStudent = testStudent.copyWith(firstName: 'Updated');
        await expectLater(
          authenticatedService.updateStudent(updatedStudent),
          completes,
        );
        
        // Verify update
        final retrieved = await authenticatedService.getStudentById(testStudent.id);
        expect(retrieved?.firstName, equals('Updated'));
        
        // Clean up
        await authenticatedService.deleteStudent(testStudent.id, hard: true);
      }, skip: false);

      test('authenticated users can delete students', () async {
        if (!TestConfig.canRunAuthTests || !authReady) {
          print('Skipping: auth not ready');
          return;
        }
        final testStudent = TestDataFactory.createTestStudent();
        
        // Create student first
        await authenticatedService.createStudent(testStudent);
        
        // Delete student
        await expectLater(
          authenticatedService.deleteStudent(testStudent.id),
          completes,
        );
        
        // Clean up (hard delete)
        await authenticatedService.deleteStudent(testStudent.id, hard: true);
      }, skip: false);

      test('authenticated users can create subscriptions', () async {
        if (!TestConfig.canRunAuthTests || !authReady) {
          print('Skipping: auth not ready');
          return;
        }
        final testStudent = TestDataFactory.createTestStudent();
        final testSubscription = TestDataFactory.createTestSubscription(
          studentId: testStudent.id,
        );
        
        // Create student first
        await authenticatedService.createStudent(testStudent);
        
        // Create subscription
        await expectLater(
          authenticatedService.createSubscription(testSubscription),
          completes,
        );
        
        // Clean up
        await authenticatedService.deleteSubscription(testSubscription.id, hard: true);
        await authenticatedService.deleteStudent(testStudent.id, hard: true);
      }, skip: false);

      test('authenticated users can create activity logs', () async {
        if (!TestConfig.canRunAuthTests || !authReady) {
          print('Skipping: auth not ready');
          return;
        }
        final testLog = TestDataFactory.createTestActivityLog();
        
        await expectLater(
          authenticatedService.createActivityLog(testLog),
          completes,
        );
        
        // Clean up
        await authenticatedService.deleteActivityLog(testLog.id);
      }, skip: false);

      test('authenticated users can access sync metadata', () async {
        if (!TestConfig.canRunAuthTests || !authReady) {
          print('Skipping: auth not ready');
          return;
        }
        final now = DateTime.now();
        
        await expectLater(
          authenticatedService.updateLastSyncTime(now),
          completes,
        );
        
        final retrievedTime = await authenticatedService.getLastSyncTime();
        expect(retrievedTime, isNotNull);
      }, skip: false);
    });

    group('Data Isolation', () {
      test('users can only see their own sync metadata', () async {
        // This test would require multiple user accounts
        // For now, we'll test that sync metadata is user-specific
        
        if (!TestConfig.canRunIntegrationTests) return;
        if (!TestConfig.canRunAuthTests) return;
        
        // Sign in and set sync time
        await authenticatedService.signInWithPassword(
          TestConfig.testUserEmail,
          TestConfig.testUserPassword,
        );
        
        if (supabaseClient.auth.currentUser == null) {
          print('Skipping: auth not ready');
          return;
        }
        
        final userSyncTime = DateTime.now();
        await authenticatedService.updateLastSyncTime(userSyncTime);
        
        // Sign out
        await authenticatedService.signOut();
        
        // As anonymous user, should not see the sync time
        final anonymousSyncTime = await supabaseService.getLastSyncTime();
        expect(anonymousSyncTime, isNull);
      }, skip: false);
    });

    group('Permission Verification', () {
      test('verify table permissions are correctly set', () async {
        // This test checks that the basic table permissions are working
        // by attempting operations that should succeed/fail based on auth state
        
        // Test as anonymous user
        await supabaseService.signOut();
        
        // Should be able to read
        await expectLater(
          supabaseService.getAllStudents(),
          completes,
        );
        
        // Should not be able to write
        final testStudent = TestDataFactory.createTestStudent();
        expect(
          () => supabaseService.createStudent(testStudent),
          throwsA(isA<Exception>()),
        );
      });

      test('verify RLS policies are enabled on all tables', () async {
        // This test verifies that RLS is actually enabled
        // by checking that operations behave differently for auth states
        
        final testStudent = TestDataFactory.createTestStudent();
        
        // As anonymous user, creation should fail
        await supabaseService.signOut();
        expect(
          () => supabaseService.createStudent(testStudent),
          throwsA(isA<Exception>()),
        );
        
        if (TestConfig.canRunAuthTests) {
          // As authenticated user, creation should succeed
          try {
            await authenticatedService.signInWithPassword(
              TestConfig.testUserEmail,
              TestConfig.testUserPassword,
            );
          } catch (e) {
            // If sign in fails in CI or constrained envs, skip the authenticated portion
            print('Skipping authenticated portion: failed to sign in: $e');
            return;
          }
          
          if (supabaseClient.auth.currentUser == null) {
            print('Skipping authenticated portion: no authenticated session after sign-in');
            return;
          }
          
          await expectLater(
            authenticatedService.createStudent(testStudent),
            completes,
          );
          
          // Clean up
          await authenticatedService.deleteStudent(testStudent.id, hard: true);
          await authenticatedService.signOut();
        }
      });
    });

    group('Edge Cases', () {
      test('handles invalid authentication gracefully', () async {
        // Test with invalid credentials
        expect(
          () => supabaseService.signInWithPassword(
            'invalid@example.com',
            'wrongpassword',
          ),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('handles expired sessions gracefully', () async {
        // This test would require session manipulation
        // For now, we'll test that the service handles auth errors
        
        await supabaseService.signOut();
        
        // Operations requiring auth should fail gracefully
        final testStudent = TestDataFactory.createTestStudent();
        expect(
          () => supabaseService.createStudent(testStudent),
          throwsA(isA<Exception>()),
        );
      });

      test('handles concurrent access correctly', () async {
        // Test that multiple operations don't interfere with each other
        if (!TestConfig.canRunAuthTests) return;
        
        try {
          await authenticatedService.signInWithPassword(
            TestConfig.testUserEmail,
            TestConfig.testUserPassword,
          );
        } catch (e) {
          print('Skipping concurrent access test: sign-in failed: $e');
          return;
        }
        
        if (supabaseClient.auth.currentUser == null) {
          print('Skipping concurrent access test: no authenticated session after sign-in');
          return;
        }
        
        final students = List.generate(3, (i) => 
          TestDataFactory.createTestStudent(id: 'concurrent-$i-${DateTime.now().millisecondsSinceEpoch}'));
        
        // Create students concurrently
        final futures = students.map((s) => authenticatedService.createStudent(s));
        await Future.wait(futures);
        
        // Verify all were created
        for (final student in students) {
          final retrieved = await authenticatedService.getStudentById(student.id);
          expect(retrieved, isNotNull);
          
          // Clean up
          await authenticatedService.deleteStudent(student.id, hard: true);
        }
        
        await authenticatedService.signOut();
      });
    });
  });
}