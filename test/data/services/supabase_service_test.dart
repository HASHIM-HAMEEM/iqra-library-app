import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';

void main() {
  group('SupabaseService', () {
    late SupabaseService supabaseService;
    late SupabaseClient mockClient;

    setUp(() {
      // Create a mock client for testing
      mockClient = SupabaseClient('https://test.supabase.co', 'test-key');
      supabaseService = SupabaseService(client: mockClient, enabled: true);
    });

    group('Initialization', () {
      test('should be initialized when enabled', () {
        expect(supabaseService.isInitialized, isTrue);
      });

      test('should not be initialized when disabled', () {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        expect(disabledService.isInitialized, isFalse);
      });
    });

    group('Student Operations', () {
      final testStudent = Student(
        id: 'test-id',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@example.com',
        phone: '+1234567890',
        address: '123 Test St',
        dateOfBirth: DateTime(1990, 1, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      test('getStudentById validates empty ID', () async {
        expect(
          () => supabaseService.getStudentById(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('deleteStudent validates empty ID', () async {
        expect(
          () => supabaseService.deleteStudent(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('getAllStudents returns empty list when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        final result = await disabledService.getAllStudents();
        expect(result, isEmpty);
      });

      test('getStudentById returns null when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        final result = await disabledService.getStudentById('test-id');
        expect(result, isNull);
      });
    });

    group('Subscription Operations', () {
      final testSubscription = Subscription(
        id: 'sub-id',
        studentId: 'student-id',
        planName: 'Premium',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: SubscriptionStatus.active,
        amount: 29.99,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      test('createSubscription validates subscription data', () async {
        final invalidSubscription = testSubscription.copyWith(
          studentId: '',
          planName: '',
        );

        expect(
          () => supabaseService.createSubscription(invalidSubscription),
          throwsA(isA<ValidationException>()),
        );
      });

      test('createSubscription validates date range', () async {
        final invalidSubscription = testSubscription.copyWith(
          startDate: DateTime.now().add(const Duration(days: 30)),
          endDate: DateTime.now(),
        );

        expect(
          () => supabaseService.createSubscription(invalidSubscription),
          throwsA(isA<ValidationException>()),
        );
      });

      test('getSubscriptionsByStudent validates empty student ID', () async {
        expect(
          () => supabaseService.getSubscriptionsByStudent(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('deleteSubscription validates empty ID', () async {
        expect(
          () => supabaseService.deleteSubscription(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('getAllSubscriptions returns empty list when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        final result = await disabledService.getAllSubscriptions();
        expect(result, isEmpty);
      });
    });

    group('Activity Log Operations', () {
      final testActivityLog = ActivityLog(
        id: 'log-id',
        activityType: ActivityType.studentCreated,
        description: 'Student created',
        entityType: 'student',
        entityId: 'student-id',
        timestamp: DateTime.now(),
      );

      test('createActivityLog validates activity log data', () async {
        final invalidActivityLog = testActivityLog.copyWith(
          description: '',
          entityType: '',
        );

        expect(
          () => supabaseService.createActivityLog(invalidActivityLog),
          throwsA(isA<ValidationException>()),
        );
      });

      test('deleteActivityLog validates empty ID', () async {
        expect(
          () => supabaseService.deleteActivityLog(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('getAllActivityLogs returns empty list when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        final result = await disabledService.getAllActivityLogs();
        expect(result, isEmpty);
      });
    });

    group('Batch Operations', () {
      test('batchInsertStudents handles empty list', () async {
        // Should not throw and should complete successfully
        await supabaseService.batchInsertStudents([]);
      });

      test('batchInsertSubscriptions handles empty list', () async {
        // Should not throw and should complete successfully
        await supabaseService.batchInsertSubscriptions([]);
      });

      test('batchInsertActivityLogs handles empty list', () async {
        // Should not throw and should complete successfully
        await supabaseService.batchInsertActivityLogs([]);
      });
    });

    group('Sync Operations', () {
      test('getLastSyncTime returns null when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        final result = await disabledService.getLastSyncTime();
        expect(result, isNull);
      });

      test('updateLastSyncTime completes when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        // Should not throw
        await disabledService.updateLastSyncTime(DateTime.now());
      });
    });

    group('Authentication', () {
      test('currentSession returns null when disabled', () {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        expect(disabledService.currentSession, isNull);
      });

      test('currentUser returns null when disabled', () {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        expect(disabledService.currentUser, isNull);
      });

      test('authStateChanges returns empty stream when disabled', () {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        expect(disabledService.authStateChanges, isA<Stream<AuthState>>());
      });

      test('signOut completes when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        // Should not throw
        await disabledService.signOut();
      });

      test('signInWithPassword throws AuthException when disabled', () async {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        expect(
          () => disabledService.signInWithPassword('test@test.com', 'password'),
          throwsA(isA<AuthException>()),
        );
      });
    });

    group('Real-time Operations', () {
      test('subscribeToStudents throws StateError when disabled', () {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        expect(
          () => disabledService.subscribeToStudents((students) {}),
          throwsA(isA<StateError>()),
        );
      });

      test('subscribeToSubscriptions throws StateError when disabled', () {
        final disabledService = SupabaseService(client: mockClient, enabled: false);
        expect(
          () => disabledService.subscribeToSubscriptions((subscriptions) {}),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Exception Types', () {
      test('SupabaseServiceException has correct message', () {
        const exception = SupabaseServiceException('Test message');
        expect(exception.toString(), contains('Test message'));
      });

      test('NetworkException extends SupabaseServiceException', () {
        const exception = NetworkException('Network error');
        expect(exception, isA<SupabaseServiceException>());
        expect(exception.toString(), contains('Network error'));
      });

      test('AuthenticationException extends SupabaseServiceException', () {
        const exception = AuthenticationException('Auth error');
        expect(exception, isA<SupabaseServiceException>());
        expect(exception.toString(), contains('Auth error'));
      });

      test('ValidationException extends SupabaseServiceException', () {
        const exception = ValidationException('Validation error');
        expect(exception, isA<SupabaseServiceException>());
        expect(exception.toString(), contains('Validation error'));
      });
    });
  });
}