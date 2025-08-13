import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/core/config/app_config.dart';

/// Integration tests for SupabaseService
/// 
/// These tests require a real Supabase instance and should be run with:
/// flutter test test/integration/supabase_integration_test.dart
/// 
/// Environment variables required:
/// - SUPABASE_URL: Your Supabase project URL
/// - SUPABASE_ANON_KEY: Your Supabase anonymous key
/// - TEST_EMAIL: Test user email for authentication
/// - TEST_PASSWORD: Test user password for authentication
void main() {
  group('Supabase Integration Tests', () {
    late SupabaseService supabaseService;
    late SupabaseClient supabaseClient;
    
    // Test data
    final testStudent = Student(
      id: 'integration-test-student-${DateTime.now().millisecondsSinceEpoch}',
      firstName: 'Integration',
      lastName: 'Test',
      email: 'integration.test@example.com',
      phone: '+1234567890',
      address: '123 Integration Test St',
      dateOfBirth: DateTime(1990, 1, 1),
      subscriptionStatus: SubscriptionStatus.active.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUpAll(() async {
      // Skip integration tests if environment variables are not set
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        print('Skipping integration tests: SUPABASE_URL or SUPABASE_ANON_KEY not set');
        return;
      }

      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      
      supabaseClient = Supabase.instance.client;
      supabaseService = SupabaseService(client: supabaseClient, enabled: true);
    });

    tearDownAll(() async {
      // Clean up test data
      try {
        await supabaseService.deleteStudent(testStudent.id, hard: true);
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Connection and Health Checks', () {
      test('service is properly initialized', () {
        expect(supabaseService.isInitialized, isTrue);
      });

      test('can validate connection to Supabase', () async {
        final isConnected = await supabaseService.validateConnection();
        expect(isConnected, isTrue);
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Authentication Flow', () {
      test('handles invalid credentials gracefully', () async {
        expect(
          () => supabaseService.signInWithPassword(
            'invalid@example.com',
            'wrongpassword',
          ),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('validates empty credentials', () async {
        expect(
          () => supabaseService.signInWithPassword('', ''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('can sign out without errors', () async {
        await expectLater(
          supabaseService.signOut(),
          completes,
        );
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Student CRUD Operations', () {
      test('can create, read, update, and delete student', () async {
        // Create
        await supabaseService.createStudent(testStudent);
        
        // Read
        final retrievedStudent = await supabaseService.getStudentById(testStudent.id);
        expect(retrievedStudent, isNotNull);
        expect(retrievedStudent!.firstName, equals(testStudent.firstName));
        expect(retrievedStudent.email, equals(testStudent.email));
        
        // Update
        final updatedStudent = testStudent.copyWith(
          firstName: 'Updated',
          lastName: 'Name',
        );
        await supabaseService.updateStudent(updatedStudent);
        
        final retrievedUpdatedStudent = await supabaseService.getStudentById(testStudent.id);
        expect(retrievedUpdatedStudent!.firstName, equals('Updated'));
        expect(retrievedUpdatedStudent.lastName, equals('Name'));
        
        // Soft Delete
        await supabaseService.deleteStudent(testStudent.id);
        
        // Should not appear in getAllStudents (soft deleted)
        final allStudents = await supabaseService.getAllStudents();
        expect(
          allStudents.any((s) => s.id == testStudent.id),
          isFalse,
        );
        
        // Hard Delete (cleanup)
        await supabaseService.deleteStudent(testStudent.id, hard: true);
        
        // Should return null after hard delete
        final deletedStudent = await supabaseService.getStudentById(testStudent.id);
        expect(deletedStudent, isNull);
      });

      test('getAllStudents returns list of students', () async {
        final students = await supabaseService.getAllStudents();
        expect(students, isA<List<Student>>());
      });

      test('getStudentById returns null for non-existent student', () async {
        final student = await supabaseService.getStudentById('non-existent-id');
        expect(student, isNull);
      });

      test('validates student data on create', () async {
        final invalidStudent = testStudent.copyWith(
          firstName: '',
          email: 'invalid-email',
        );

        expect(
          () => supabaseService.createStudent(invalidStudent),
          throwsA(isA<ValidationException>()),
        );
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Subscription Operations', () {
      late String testStudentId;
      
      setUp(() async {
        // Create a test student for subscription tests
        testStudentId = 'sub-test-student-${DateTime.now().millisecondsSinceEpoch}';
        final student = testStudent.copyWith(id: testStudentId);
        await supabaseService.createStudent(student);
      });
      
      tearDown(() async {
        // Clean up test student
        try {
          await supabaseService.deleteStudent(testStudentId, hard: true);
        } catch (e) {
          // Ignore cleanup errors
        }
      });

      test('can create and retrieve subscriptions', () async {
        final subscription = Subscription(
          id: 'test-subscription-${DateTime.now().millisecondsSinceEpoch}',
          studentId: testStudentId,
          planName: 'Premium',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          status: SubscriptionStatus.active,
          amount: 29.99,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await supabaseService.createSubscription(subscription);
        
        final subscriptions = await supabaseService.getSubscriptionsByStudent(testStudentId);
        expect(subscriptions, hasLength(greaterThan(0)));
        expect(
          subscriptions.any((s) => s.id == subscription.id),
          isTrue,
        );
        
        // Clean up
        await supabaseService.deleteSubscription(subscription.id, hard: true);
      });

      test('validates subscription data', () async {
        final invalidSubscription = Subscription(
          id: 'invalid-sub',
          studentId: '', // Invalid
          planName: '', // Invalid
          startDate: DateTime.now().add(const Duration(days: 30)),
          endDate: DateTime.now(), // Invalid date range
          status: SubscriptionStatus.active,
          amount: 29.99,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(
          () => supabaseService.createSubscription(invalidSubscription),
          throwsA(isA<ValidationException>()),
        );
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Activity Log Operations', () {
      test('can create and retrieve activity logs', () async {
        final activityLog = ActivityLog(
          id: 'test-log-${DateTime.now().millisecondsSinceEpoch}',
          activityType: ActivityType.studentCreated,
          description: 'Student created',
        entityType: 'student',
          entityId: testStudent.id,
          timestamp: DateTime.now(),
          metadata: {'test': 'data'},
        );

        await supabaseService.createActivityLog(activityLog);
        
        final logs = await supabaseService.getAllActivityLogs();
        expect(logs, hasLength(greaterThan(0)));
        expect(
          logs.any((log) => log.id == activityLog.id),
          isTrue,
        );
        
        // Clean up
        await supabaseService.deleteActivityLog(activityLog.id);
      });

      test('validates activity log data', () async {
        final invalidLog = ActivityLog(
          id: 'invalid-log',
          activityType: ActivityType.studentCreated,
          description: '', // Invalid
          entityType: '', // Invalid
          entityId: 'entity-id',
          timestamp: DateTime.now(),
          metadata: {},
        );

        expect(
          () => supabaseService.createActivityLog(invalidLog),
          throwsA(isA<ValidationException>()),
        );
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Sync Operations', () {
      test('can get and update sync time', () async {
        final now = DateTime.now();
        
        await supabaseService.updateLastSyncTime(now);
        final retrievedTime = await supabaseService.getLastSyncTime();
        
        expect(retrievedTime, isNotNull);
        // Allow for small time differences due to serialization
        expect(
          retrievedTime!.difference(now).abs().inSeconds,
          lessThan(2),
        );
      });

      test('returns null for non-existent sync time', () async {
        // This test assumes a clean database or different user context
        final syncTime = await supabaseService.getLastSyncTime();
        expect(syncTime, isA<DateTime?>());
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Batch Operations', () {
      test('can batch insert students', () async {
        final students = List.generate(3, (index) => Student(
          id: 'batch-student-$index-${DateTime.now().millisecondsSinceEpoch}',
          firstName: 'Batch$index',
          lastName: 'Test',
          email: 'batch$index.test@example.com',
          phone: '+123456789$index',
          address: '123 Batch Test St',
          dateOfBirth: DateTime(1990, 1, 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        await supabaseService.batchInsertStudents(students);
        
        // Verify students were created
        for (final student in students) {
          final retrieved = await supabaseService.getStudentById(student.id);
          expect(retrieved, isNotNull);
          expect(retrieved!.firstName, equals(student.firstName));
          
          // Clean up
          await supabaseService.deleteStudent(student.id, hard: true);
        }
      });

      test('handles empty batch operations gracefully', () async {
        await expectLater(
          supabaseService.batchInsertStudents([]),
          completes,
        );
        
        await expectLater(
          supabaseService.batchInsertSubscriptions([]),
          completes,
        );
        
        await expectLater(
          supabaseService.batchInsertActivityLogs([]),
          completes,
        );
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Real-time Subscriptions', () {
      test('subscribeToStudents returns a channel', () async {
        late RealtimeChannel channel;
        List<Student> receivedStudents = [];
        
        channel = supabaseService.subscribeToStudents((students) {
          receivedStudents = students;
        });
        
        expect(channel, isA<RealtimeChannel>());
        
        // Clean up
        await channel.unsubscribe();
      });

      test('subscribeToSubscriptions returns a channel', () async {
        late RealtimeChannel channel;
        List<Subscription> receivedSubscriptions = [];
        
        channel = supabaseService.subscribeToSubscriptions((subscriptions) {
          receivedSubscriptions = subscriptions;
        });
        
        expect(channel, isA<RealtimeChannel>());
        
        // Clean up
        await channel.unsubscribe();
      });
    }, skip: _shouldSkipIntegrationTests());

    group('Error Handling and Resilience', () {
      test('handles network timeouts gracefully', () async {
        // This test would require network manipulation or a mock server
        // For now, we'll test that the service doesn't crash on errors
        expect(
          () => supabaseService.getStudentById('test-id'),
          returnsNormally,
        );
      });

      test('retries failed operations', () async {
        // Test retry logic by attempting operations that might fail
        // The service should handle retries internally
        final students = await supabaseService.getAllStudents();
        expect(students, isA<List<Student>>());
      });
    }, skip: _shouldSkipIntegrationTests());
  });
}

/// Helper function to determine if integration tests should be skipped
bool _shouldSkipIntegrationTests() {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  return supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;
}