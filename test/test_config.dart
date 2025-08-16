import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';



/// Test configuration and utilities for the Iqra Library App
class TestConfig {
  static const String testEmail = 'test@example.com';
  static const String testPassword = 'testpassword123';
  
  /// Environment variables for integration tests
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String testUserEmail = String.fromEnvironment('TEST_EMAIL');
  static const String testUserPassword = String.fromEnvironment('TEST_PASSWORD');
  
  /// Check if integration tests can be run
  static bool get canRunIntegrationTests {
    return supabaseUrl.isNotEmpty && 
           supabaseAnonKey.isNotEmpty;
  }
  
  /// Check if authentication tests can be run
  static bool get canRunAuthTests {
    return canRunIntegrationTests && 
           testUserEmail.isNotEmpty && 
           testUserPassword.isNotEmpty;
  }
}

/// Test data factory for creating test entities
class TestDataFactory {
  static Student createTestStudent({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    SubscriptionStatus? status,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return Student(
      id: id ?? 'test-student-$timestamp',
      firstName: firstName ?? 'Test',
      lastName: lastName ?? 'Student',
      email: email ?? 'test.student$timestamp@example.com',
      phone: phone ?? '+1234567890',
      address: '123 Test Street',
      dateOfBirth: dateOfBirth ?? DateTime(1990, 1, 1),
      subscriptionStatus: status?.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  static Subscription createTestSubscription({
    String? id,
    String? studentId,
    String? planName,
    DateTime? startDate,
    DateTime? endDate,
    SubscriptionStatus? status,
    double? price,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final start = startDate ?? DateTime.now();
    return Subscription(
      id: id ?? 'test-subscription-$timestamp',
      studentId: studentId ?? 'test-student-id',
      planName: planName ?? 'Test Plan',
      startDate: start,
      endDate: endDate ?? start.add(const Duration(days: 30)),
      status: status ?? SubscriptionStatus.active,
      amount: price ?? 29.99,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  static ActivityLog createTestActivityLog({
    String? id,
    ActivityType? activityType,
    String? description,
    String? entityType,
    String? entityId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    return ActivityLog(
      id: id ?? 'test-log-$timestampMs',
      activityType: activityType ?? ActivityType.studentCreated,
      description: description ?? 'Test action performed',
      entityType: entityType ?? 'TestEntity',
      entityId: entityId ?? 'test-entity-id',
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata,
    );
  }
}

/// Test utilities for common test operations
class TestUtils {
  /// Initialize Supabase for testing
  static Future<SupabaseClient?> initializeSupabaseForTesting() async {
    if (!TestConfig.canRunIntegrationTests) {
      return null;
    }
    
    try {
      await Supabase.initialize(
        url: TestConfig.supabaseUrl,
        anonKey: TestConfig.supabaseAnonKey,
      );
      
      return Supabase.instance.client;
    } catch (e) {
      print('Failed to initialize Supabase for testing: $e');
      return null;
    }
  }
  
  /// Clean up test data
  static Future<void> cleanupTestData(
    SupabaseService service,
    List<String> studentIds, {
    List<String>? subscriptionIds,
    List<String>? activityLogIds,
  }) async {
    // Clean up students (this will cascade to related data)
    for (final id in studentIds) {
      try {
        await service.deleteStudent(id, hard: true);
      } catch (e) {
        print('Failed to cleanup student $id: $e');
      }
    }
    
    // Clean up subscriptions
    if (subscriptionIds != null) {
      for (final id in subscriptionIds) {
        try {
          await service.deleteSubscription(id, hard: true);
        } catch (e) {
          print('Failed to cleanup subscription $id: $e');
        }
      }
    }
    
    // Clean up activity logs
    if (activityLogIds != null) {
      for (final id in activityLogIds) {
        try {
          await service.deleteActivityLog(id);
        } catch (e) {
          print('Failed to cleanup activity log $id: $e');
        }
      }
    }
  }
  
  /// Wait for a condition to be true with timeout
  static Future<bool> waitForCondition(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      try {
        if (await condition()) {
          return true;
        }
      } catch (e) {
        // Ignore errors and continue waiting
      }
      
      await Future.delayed(interval);
    }
    
    return false;
  }
  
  /// Generate unique test identifier
  static String generateTestId([String? prefix]) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix ?? 'test'}-$timestamp';
  }
  
  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  /// Create a test matcher for SupabaseServiceException
  static Matcher throwsSupabaseServiceException([String? message]) {
    return throwsA(
      allOf(
        isA<SupabaseServiceException>(),
        message != null
            ? predicate<SupabaseServiceException>(
                (e) => e.message.contains(message),
                'message contains "$message"',
              )
            : anything,
      ),
    );
  }
  
  /// Create a test matcher for ValidationException
  static Matcher throwsValidationException([String? message]) {
    return throwsA(
      allOf(
        isA<ValidationException>(),
        message != null
            ? predicate<ValidationException>(
                (e) => e.message.contains(message),
                'message contains "$message"',
              )
            : anything,
      ),
    );
  }
  
  /// Create a test matcher for NetworkException
  static Matcher throwsNetworkException([String? message]) {
    return throwsA(
      allOf(
        isA<NetworkException>(),
        message != null
            ? predicate<NetworkException>(
                (e) => e.message.contains(message),
                'message contains "$message"',
              )
            : anything,
      ),
    );
  }
  
  /// Create a test matcher for AuthenticationException
  static Matcher throwsAuthenticationException([String? message]) {
    return throwsA(
      allOf(
        isA<AuthenticationException>(),
        message != null
            ? predicate<AuthenticationException>(
                (e) => e.message.contains(message),
                'message contains "$message"',
              )
            : anything,
      ),
    );
  }
}

/// Test group wrapper that can be conditionally skipped
void testGroup(
  String description,
  void Function() body, {
  bool skip = false,
  String? skipReason,
}) {
  group(
    description,
    body,
    skip: skip ? (skipReason ?? 'Test group skipped') : null,
  );
}

/// Integration test wrapper that skips if environment is not configured
void integrationTestGroup(
  String description,
  void Function() body, {
  bool requiresAuth = false,
}) {
  final shouldSkip = requiresAuth 
      ? !TestConfig.canRunAuthTests 
      : !TestConfig.canRunIntegrationTests;
      
  final skipReason = requiresAuth
      ? 'Integration tests with auth require SUPABASE_URL, SUPABASE_ANON_KEY, TEST_EMAIL, and TEST_PASSWORD environment variables'
      : 'Integration tests require SUPABASE_URL and SUPABASE_ANON_KEY environment variables';
      
  testGroup(
    description,
    body,
    skip: shouldSkip,
    skipReason: skipReason,
  );
}