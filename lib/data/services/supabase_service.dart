 
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:library_registration_app/core/services/connectivity_service.dart';
 
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';

// Custom exceptions for better error handling
class SupabaseServiceException implements Exception {
  const SupabaseServiceException(this.message, {this.details});
  final String message;
  final Map<String, dynamic>? details;
  
  @override
  String toString() => 'SupabaseServiceException: $message${details != null ? ' Details: $details' : ''}';
}

class NetworkException extends SupabaseServiceException {
  const NetworkException(super.message, {super.details});
}

class AuthenticationException extends SupabaseServiceException {
  const AuthenticationException(super.message, {super.details});
}

class ValidationException extends SupabaseServiceException {
  const ValidationException(super.message, {super.details});
}

class SupabaseService {
  SupabaseService({required SupabaseClient client, bool enabled = true})
      : _client = client,
        _enabled = enabled;

  final SupabaseClient _client;
  final bool _enabled;
  
  /// Check if Supabase is properly initialized
  bool get isInitialized => _enabled;
  
  /// Validate connection to Supabase
  Future<bool> validateConnection() async {
    if (!_enabled) return false;
    try {
      // Simple query to test connection
      await _client.from('students').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('SupabaseService: Connection validation failed: $e');
      return false;
    }
  }
  
  /// Execute operations with retry logic and comprehensive error handling
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    required String operationName,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    if (!isInitialized) {
      throw const SupabaseServiceException('Supabase service is not properly initialized');
    }
    
    // Check connectivity before attempting operation
    final connectivityService = ConnectivityService.instance;
    if (!connectivityService.hasConnection) {
      // Wait for connection with timeout
      final hasConnection = await connectivityService.waitForConnection(
        timeout: const Duration(seconds: 10),
      );
      if (!hasConnection) {
        throw const NetworkException(
          'No internet connection available. Please check your network settings.',
        );
      }
    }
    
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        debugPrint('SupabaseService: $operationName attempt $attempts failed: $e');
        
        // Handle specific error types
        if (e is AuthException) {
          throw AuthenticationException(
            'Authentication failed during $operationName',
            details: {'originalError': e.toString(), 'attempt': attempts},
          );
        }
        
        if (e is PostgrestException) {
          // Don't retry for client errors (4xx)
          if (e.code != null && e.code!.startsWith('4')) {
            throw ValidationException(
              'Invalid request during $operationName: ${e.message}',
              details: {'code': e.code, 'hint': e.hint},
            );
          }
        }
        
        // Network-related errors
        if (e is DioException || e.toString().contains('SocketException') || 
            e.toString().contains('TimeoutException') ||
            e.toString().contains('Connection refused')) {
          
          // Check if we still have connectivity
          if (!connectivityService.hasConnection) {
            debugPrint('Lost connectivity during $operationName, waiting for reconnection...');
            final reconnected = await connectivityService.waitForConnection(
              timeout: Duration(seconds: 5 * attempts), // Increase timeout with attempts
            );
            if (!reconnected && attempts >= maxRetries) {
              throw NetworkException(
                'Network connection lost during $operationName. ${connectivityService.connectionStatusText}',
                details: {'originalError': e.toString(), 'attempts': attempts},
              );
            }
          }
          
          if (attempts >= maxRetries) {
            throw NetworkException(
              'Network error during $operationName after $attempts attempts. ${connectivityService.connectionStatusText}',
              details: {'originalError': e.toString()},
            );
          }
          
          // Exponential backoff for network errors
          final backoffDelay = Duration(
            milliseconds: (retryDelay.inMilliseconds * (attempts * attempts)).clamp(1000, 10000),
          );
          debugPrint('Retrying $operationName in ${backoffDelay.inSeconds}s (attempt ${attempts + 1}/$maxRetries)');
          await Future<void>.delayed(backoffDelay);
          continue;
        }
        
        // For other errors, don't retry if it's the last attempt
        if (attempts >= maxRetries) {
          throw SupabaseServiceException(
            'Operation $operationName failed after $attempts attempts',
            details: {'originalError': e.toString()},
          );
        }
        
        // Wait before retry
        await Future<void>.delayed(retryDelay);
      }
    }
    
    throw SupabaseServiceException('Unexpected error in $operationName');
  }

  // Authentication
  Future<void> signInWithPassword(String email, String password) async {
    if (!_enabled) {
      throw const AuthException('Supabase is disabled in this build');
    }
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (!_enabled) return;
    await _client.auth.signOut();
  }

  Session? get currentSession => _enabled ? _client.auth.currentSession : null;
  User? get currentUser => _enabled ? _client.auth.currentUser : null;
  
  Stream<AuthState> get authStateChanges =>
      _enabled ? _client.auth.onAuthStateChange : const Stream.empty();

  // Students CRUD
  Future<String> uploadProfileImage({
    required String studentId,
    required File file,
  }) async {
    if (!_enabled) {
      throw const SupabaseServiceException('Supabase is disabled');
    }
    return _executeWithRetry(
      () async {
        final String ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final String storagePath = 'students/$studentId/$fileName';
        await _client.storage
            .from('profile-images')
            .upload(storagePath, file, fileOptions: const FileOptions(upsert: true, cacheControl: '3600'));
        final String publicUrl = _client.storage.from('profile-images').getPublicUrl(storagePath);
        return publicUrl;
      },
      operationName: 'uploadProfileImage',
    );
  }

  Future<void> updateStudentProfileImage(String studentId, String? publicUrl) async {
    if (!_enabled) return;
    if (studentId.trim().isEmpty) {
      throw const ValidationException('Student ID cannot be empty');
    }
    return _executeWithRetry(
      () => _client
          .from('students')
          .update({'profile_image_path': publicUrl, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', studentId),
      operationName: 'updateStudentProfileImage',
    );
  }
  Future<List<Student>> getAllStudents() async {
    if (!_enabled) return <Student>[];
    return _executeWithRetry(
      () async {
      final response = await _client
          .from('students')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false);
      
      return (response as List)
            .map((json) {
              try {
                return Student.fromJson(json as Map<String, dynamic>);
    } catch (e) {
                throw ValidationException(
                  'Failed to parse student data',
                  details: {'studentData': json, 'parseError': e.toString()},
                );
              }
            })
            .toList();
      },
      operationName: 'getAllStudents',
    );
  }

  Future<Student?> getStudentById(String id) async {
    if (!_enabled) return null;
    if (id.trim().isEmpty) {
      throw const ValidationException('Student ID cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
    try {
      final response = await _client
          .from('students')
          .select()
          .eq('id', id)
          .single();
      
      return Student.fromJson(response);
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST116') {
            // No student found
      return null;
    }
          rethrow;
        }
      },
      operationName: 'getStudentById',
    );
  }

  Future<void> createStudent(Student student) async {
    if (!_enabled) return;
    
    // Debug: Check authentication state
    final user = currentUser;
    final session = currentSession;
    print('SupabaseService: createStudent - User: ${user?.id}, Session: ${session?.accessToken != null ? "Valid" : "Invalid"}');
    
    if (user == null || session == null) {
      throw const AuthException('User not authenticated. Please sign in first.');
    }
    
    // Debug: Test authentication context in database
    try {
      final authTest = await _client.rpc<Map<String, dynamic>>('get_current_user_info');
      print('SupabaseService: Database auth context: $authTest');
    } catch (e) {
      print('SupabaseService: Failed to get auth context: $e');
    }
    
    return _executeWithRetry(
      () => _client.from('students').insert(student.toJson()),
      operationName: 'createStudent',
    );
  }

  Future<void> updateStudent(Student student) async {
    if (!_enabled) return;
    return _executeWithRetry(
      () => _client
          .from('students')
          .update(student.toJson())
          .eq('id', student.id),
      operationName: 'updateStudent',
    );
  }

  Future<void> deleteStudent(String id, {bool hard = false}) async {
    if (!_enabled) return;
    if (id.trim().isEmpty) {
      throw const ValidationException('Student ID cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
      if (hard) {
          await _client.from('students').delete().eq('id', id);
      } else {
        await _client
            .from('students')
            .update({
              'is_deleted': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
      }
      },
      operationName: 'deleteStudent',
    );
  }

  Future<List<Student>> getActiveStudents() async {
    if (!_enabled) return <Student>[];
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('students')
            .select()
            .eq('is_deleted', false)
            .order('created_at', ascending: false);
        
        return (response as List)
            .map((json) => Student.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getActiveStudents',
    );
  }

  Future<List<Student>> searchStudents(String query) async {
    if (!_enabled) return <Student>[];
    if (query.trim().isEmpty) return <Student>[];
    
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('students')
            .select('id, first_name, last_name, email, phone, address, profile_image_path, seat_number, created_at, updated_at, date_of_birth, is_deleted')
            .eq('is_deleted', false)
            .or('first_name.ilike.%$query%,last_name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
            .order('created_at', ascending: false);
        
        return (response as List)
            .map((json) => Student.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'searchStudents',
    );
  }

  Future<List<Student>> getStudentsPaginated(int offset, int limit) async {
    if (!_enabled) return <Student>[];
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('students')
            .select('id, first_name, last_name, email, phone, address, profile_image_path, seat_number, created_at, updated_at, date_of_birth, is_deleted')
            .eq('is_deleted', false)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        
        return (response as List)
            .map((json) => Student.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getStudentsPaginated',
    );
  }

  Future<int> getStudentsCount() async {
    if (!_enabled) return 0;
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('students')
            .select('id')
            .eq('is_deleted', false)
            .count();
        return response.count;
      },
      operationName: 'getStudentsCount',
    );
  }

  Future<bool> isEmailExists(String email, {String? excludeId}) async {
    if (!_enabled) return false;
    if (email.trim().isEmpty) return false;
    
    return _executeWithRetry(
      () async {
        var query = _client
            .from('students')
            .select('id')
            .eq('email', email.toLowerCase())
            .eq('is_deleted', false);
        
        if (excludeId != null && excludeId.trim().isNotEmpty) {
          query = query.neq('id', excludeId);
        }
        
        final response = await query;
        return (response as List).isNotEmpty;
      },
      operationName: 'isEmailExists',
    );
  }

  Future<List<Student>> getStudentsByAgeRange(int minAge, int maxAge) async {
    if (!_enabled) return <Student>[];
    return _executeWithRetry(
      () async {
        final now = DateTime.now();
        final maxBirthDate = DateTime(now.year - minAge, now.month, now.day);
        final minBirthDate = DateTime(now.year - maxAge, now.month, now.day);
        
        final response = await _client
            .from('students')
            .select()
            .eq('is_deleted', false)
            .gte('date_of_birth', minBirthDate.toIso8601String())
            .lte('date_of_birth', maxBirthDate.toIso8601String())
            .order('created_at', ascending: false);
        
        return (response as List)
            .map((json) => Student.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getStudentsByAgeRange',
    );
  }

  Future<List<Student>> getRecentStudents(int days) async {
    if (!_enabled) return <Student>[];
    return _executeWithRetry(
      () async {
        final cutoffDate = DateTime.now().subtract(Duration(days: days));
        
        final response = await _client
            .from('students')
            .select()
            .eq('is_deleted', false)
            .gte('created_at', cutoffDate.toIso8601String())
            .order('created_at', ascending: false);
        
        return (response as List)
            .map((json) => Student.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getRecentStudents',
    );
  }

  Future<void> restoreStudent(String id) async {
    if (!_enabled) return;
    if (id.trim().isEmpty) {
      throw const ValidationException('Student ID cannot be empty');
    }
    
    return _executeWithRetry(
      () => _client
          .from('students')
          .update({
            'is_deleted': false,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', id),
      operationName: 'restoreStudent',
    );
  }

  Stream<List<Student>> watchAllStudents() {
    if (!_enabled) return Stream.value(<Student>[]);
    
    return _client
        .from('students')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((json) => Student.fromJson(json))
            .toList());
  }

  Stream<List<Student>> watchActiveStudents() {
    if (!_enabled) return Stream.value(<Student>[]);
    
    return _client
        .from('students')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .where((json) => json['is_deleted'] == false)
            .map((json) => Student.fromJson(json))
            .toList());
  }

  Stream<Student?> watchStudentById(String id) {
    if (!_enabled) return Stream.value(null);
    if (id.trim().isEmpty) return Stream.value(null);
    
    return _client
        .from('students')
        .stream(primaryKey: ['id'])
        .map((data) {
          final filtered = data.where((json) => json['id'] == id && json['is_deleted'] == false).toList();
          if (filtered.isEmpty) return null;
          return Student.fromJson(filtered.first);
        });
  }

  // Subscriptions CRUD
  Future<List<Subscription>> getAllSubscriptions() async {
    if (!_enabled) return <Subscription>[];
    return _executeWithRetry(
      () async {
      final response = await _client
          .from('subscriptions')
           .select('id, student_id, plan_name, start_date, end_date, amount, status, created_at, updated_at')
          .order('created_at', ascending: false);
      
        
      
      return (response as List)
            .map((json) {
              try {
                return Subscription.fromJson(json as Map<String, dynamic>);
    } catch (e) {
                throw ValidationException(
                  'Failed to parse subscription data',
                  details: {'subscriptionData': json, 'parseError': e.toString()},
                );
              }
            })
            .toList();
      },
      operationName: 'getAllSubscriptions',
    );
  }

  Future<List<Subscription>> getSubscriptionsByStudent(String studentId) async {
    if (!_enabled) return <Subscription>[];
    if (studentId.trim().isEmpty) {
      throw const ValidationException('Student ID cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
      final response = await _client
          .from('subscriptions')
           .select('id, student_id, plan_name, start_date, end_date, amount, status, created_at, updated_at')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      
        
      
      return (response as List)
            .map((json) {
              try {
                return Subscription.fromJson(json as Map<String, dynamic>);
    } catch (e) {
                throw ValidationException(
                  'Failed to parse subscription data',
                  details: {'subscriptionData': json, 'parseError': e.toString()},
                );
              }
            })
            .toList();
      },
      operationName: 'getSubscriptionsByStudent',
    );
  }

  Future<void> createSubscription(Subscription subscription) async {
    if (!_enabled) return;
    _validateSubscription(subscription);
    
    return _executeWithRetry(
      () => _client.from('subscriptions').insert(subscription.toJson()),
      operationName: 'createSubscription',
    );
  }
  
  /// Validate subscription data before operations
  void _validateSubscription(Subscription subscription) {
    if (subscription.studentId.trim().isEmpty) {
      throw const ValidationException('Subscription student ID cannot be empty');
    }
    if (subscription.planName.trim().isEmpty) {
      throw const ValidationException('Subscription plan name cannot be empty');
    }
    if (subscription.startDate.isAfter(subscription.endDate)) {
      throw const ValidationException('Subscription start date cannot be after end date');
    }
  }

  Future<void> updateSubscription(Subscription subscription) async {
    if (!_enabled) return;
    _validateSubscription(subscription);
    
    return _executeWithRetry(
      () => _client
          .from('subscriptions')
          .update({
            'plan_name': subscription.planName,
            'start_date': subscription.startDate.toUtc().toIso8601String(),
            'end_date': subscription.endDate.toUtc().toIso8601String(),
            'amount': subscription.amount,
            'status': subscription.status.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', subscription.id),
      operationName: 'updateSubscription',
    );
  }

  Future<void> deleteSubscription(String id, {bool hard = false}) async {
    if (!_enabled) return;
    if (id.trim().isEmpty) {
      throw const ValidationException('Subscription ID cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
        // Perform a hard delete since subscriptions table has no is_deleted column
        await _client.from('subscriptions').delete().eq('id', id);
      },
      operationName: 'deleteSubscription',
    );
  }

  Future<List<Subscription>> getActiveSubscriptions() async {
    if (!_enabled) return <Subscription>[];
    return _executeWithRetry(
      () async {
        final now = DateTime.now();
        final response = await _client
            .from('subscriptions')
            .select('id, student_id, plan_name, end_date, amount, status, created_at')
            .gte('end_date', now.toIso8601String())
            .order('created_at', ascending: false);
        
        return (response as List)
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getActiveSubscriptions',
    );
  }

  Future<List<Subscription>> getExpiredSubscriptions() async {
    if (!_enabled) return <Subscription>[];
    return _executeWithRetry(
      () async {
        final now = DateTime.now();
        final response = await _client
            .from('subscriptions')
            .select('id, student_id, plan_name, end_date, amount, status, created_at')
            .lt('end_date', now.toIso8601String())
            .order('end_date', ascending: false);
        
        return (response as List)
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getExpiredSubscriptions',
    );
  }

  Future<List<Subscription>> getSubscriptionsByStatus(String status) async {
    if (!_enabled) return <Subscription>[];
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('subscriptions')
            .select('id, student_id, plan_name, start_date, end_date, amount, status, created_at, updated_at')
            .eq('status', status)
            .order('created_at', ascending: false);
        
        return (response as List)
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getSubscriptionsByStatus',
    );
  }

  Future<Subscription?> getSubscriptionById(String id) async {
    if (!_enabled) return null;
    if (id.trim().isEmpty) {
      throw const ValidationException('Subscription ID cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
        try {
          final response = await _client
              .from('subscriptions')
              .select('id, student_id, plan_name, start_date, end_date, amount, status, created_at, updated_at')
              .eq('id', id)
              .single();
          
          return Subscription.fromJson(response);
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST116') {
            // No subscription found
            return null;
          }
      rethrow;
    }
      },
      operationName: 'getSubscriptionById',
    );
  }

  Future<Subscription?> getActiveSubscriptionByStudent(String studentId) async {
    if (!_enabled) return null;
    if (studentId.trim().isEmpty) {
      throw const ValidationException('Student ID cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
        try {
          final now = DateTime.now();
          final response = await _client
          .from('subscriptions')
               .select('id, student_id, plan_name, start_date, end_date, amount, status, created_at, updated_at')
              .eq('student_id', studentId)
              .gte('end_date', now.toIso8601String())
              .order('end_date', ascending: false)
              .limit(1)
              .single();
          
          return Subscription.fromJson(response);
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST116') {
            // No active subscription found
            return null;
          }
      rethrow;
    }
      },
      operationName: 'getActiveSubscriptionByStudent',
    );
  }

  Future<List<Subscription>> getExpiringSubscriptions(int days) async {
    if (!_enabled) return <Subscription>[];
    return _executeWithRetry(
      () async {
        final now = DateTime.now();
        final expiryDate = now.add(Duration(days: days));
        
        final response = await _client
            .from('subscriptions')
            .select('id, student_id, plan_name, end_date, amount, status, created_at')
            .gte('end_date', now.toIso8601String())
            .lte('end_date', expiryDate.toIso8601String())
            .order('end_date', ascending: true);
        
        return (response as List)
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getExpiringSubscriptions',
    );
  }

  Future<List<Subscription>> getSubscriptionsPaginated(int offset, int limit) async {
    if (!_enabled) return <Subscription>[];
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('subscriptions')
            .select('id, student_id, plan_name, start_date, end_date, amount, status, created_at, updated_at')
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        
        return (response as List)
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getSubscriptionsPaginated',
    );
  }

  Future<int> getSubscriptionsCount() async {
    if (!_enabled) return 0;
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('subscriptions')
            .select('id')
            .count();
        return response.count;
      },
      operationName: 'getSubscriptionsCount',
    );
  }

  Future<void> restoreSubscription(String id) async {
    // Not supported: subscriptions table has no soft-delete flag.
    throw const SupabaseServiceException('Restore not supported for subscriptions');
  }

  Stream<List<Subscription>> watchAllSubscriptions() {
    if (!_enabled) return Stream.value(<Subscription>[]);
    
    return _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .map((json) => Subscription.fromJson(json))
            .toList());
  }

  Stream<List<Subscription>> watchActiveSubscriptions() {
    if (!_enabled) return Stream.value(<Subscription>[]);
    
    return _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .where((json) => json['status'] == 'active')
            .map((json) => Subscription.fromJson(json))
            .toList());
  }

  Stream<List<Subscription>> watchSubscriptionsByStudent(String studentId) {
    if (!_enabled) return Stream.value(<Subscription>[]);
    if (studentId.trim().isEmpty) return Stream.value(<Subscription>[]);
    
    return _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .where((json) => json['student_id'] == studentId)
            .map((json) => Subscription.fromJson(json))
            .toList());
  }

  Stream<Subscription?> watchSubscriptionById(String id) {
    if (!_enabled) return Stream.value(null);
    if (id.trim().isEmpty) return Stream.value(null);
    
    return _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .map((data) {
          final filtered = data.where((json) => json['id'] == id).toList();
          if (filtered.isEmpty) return null;
          return Subscription.fromJson(filtered.first);
        });
  }

  Future<void> cancelSubscription(String id) async {
    if (!_enabled) return;
    if (id.trim().isEmpty) {
      throw const ValidationException('Subscription ID cannot be empty');
    }
    
    return _executeWithRetry(
      () => _client
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id),
      operationName: 'cancelSubscription',
    );
  }

  Future<void> renewSubscription(String id, DateTime newEndDate, double amount) async {
    if (!_enabled) return;
    if (id.trim().isEmpty) {
      throw const ValidationException('Subscription ID cannot be empty');
    }
    
    return _executeWithRetry(
      () => _client
          .from('subscriptions')
          .update({
            'end_date': newEndDate.toIso8601String(),
            'amount': amount,
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id),
      operationName: 'renewSubscription',
    );
  }

  Future<int> getActiveSubscriptionsCount() async {
    if (!_enabled) return 0;
    return _executeWithRetry(
      () async {
        final now = DateTime.now();
        final response = await _client
            .from('subscriptions')
            .select('id')
            .gte('end_date', now.toIso8601String())
            .count();
        
        return response.count;
      },
      operationName: 'getActiveSubscriptionsCount',
    );
  }

  Future<double> getTotalRevenue() async {
    if (!_enabled) return 0.0;
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('subscriptions')
            .select('amount')
            ;
        
        double total = 0.0;
        for (final row in response as List) {
          total += (row['amount'] as num).toDouble();
        }
        return total;
      },
      operationName: 'getTotalRevenue',
    );
  }

  Future<double> getRevenueByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!_enabled) return 0.0;
    return _executeWithRetry(
      () async {
        // Treat revenue as sum of subscription amounts created within the range.
        // This avoids missing records where start_date/end_date fall outside the range.
        final response = await _client
            .from('subscriptions')
            .select('amount, created_at')
            .gte('created_at', startDate.toUtc().toIso8601String())
            .lte('created_at', endDate.toUtc().toIso8601String());

        double total = 0.0;
        for (final row in response as List) {
          total += (row['amount'] as num).toDouble();
        }
        return total;
      },
      operationName: 'getRevenueByDateRange',
    );
  }

  Future<List<Map<String, dynamic>>> getSubscriptionStats() async {
    if (!_enabled) return <Map<String, dynamic>>[];
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('subscriptions')
            .select('status, amount')
            ;
        
        final Map<String, Map<String, dynamic>> stats = {};
        
        for (final row in response as List) {
          final status = row['status'] as String;
          final amount = (row['amount'] as num).toDouble();
          
          if (!stats.containsKey(status)) {
            stats[status] = {'count': 0, 'total_amount': 0.0};
          }
          
          stats[status]!['count'] = (stats[status]!['count'] as int) + 1;
          stats[status]!['total_amount'] = (stats[status]!['total_amount'] as double) + amount;
        }
        
        return stats.entries
            .map((entry) => {
                  'status': entry.key,
                  'count': entry.value['count'],
                  'total_amount': entry.value['total_amount'],
                })
            .toList();
      },
      operationName: 'getSubscriptionStats',
    );
  }

  // Activity Logs CRUD
  Future<List<ActivityLog>> getAllActivityLogs() async {
    if (!_enabled) return <ActivityLog>[];
    return _executeWithRetry(
      () async {
      final response = await _client
          .from('activity_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(1000); // Limit to avoid large responses
      
        
      
      return (response as List)
            .map((json) {
              try {
                return ActivityLog.fromJson(json as Map<String, dynamic>);
    } catch (e) {
                throw ValidationException(
                  'Failed to parse activity log data',
                  details: {'activityLogData': json, 'parseError': e.toString()},
                );
              }
            })
            .toList();
      },
      operationName: 'getAllActivityLogs',
    );
  }

  Future<ActivityLog> createActivityLog(ActivityLog activityLog) async {
    if (!_enabled) throw StateError('Supabase is disabled');
    _validateActivityLog(activityLog);
    
    return _executeWithRetry(
      () async {
        final response = await _client.from('activity_logs').insert(activityLog.toJson()).select().single();
        return ActivityLog.fromJson(response);
      },
      operationName: 'createActivityLog',
    );
  }
  
  /// Validate activity log data before operations
  void _validateActivityLog(ActivityLog activityLog) {
    if (activityLog.description.trim().isEmpty) {
      throw const ValidationException('Activity log description cannot be empty');
    }
    if (activityLog.entityType?.trim().isEmpty == true) {
      throw const ValidationException('Activity log entity type cannot be empty');
    }
  }

  Future<void> deleteActivityLog(String id) async {
    if (!_enabled) return;
    if (id.trim().isEmpty) {
      throw const ValidationException('Activity log ID cannot be empty');
    }
    
    return _executeWithRetry(
      () => _client.from('activity_logs').delete().eq('id', id),
      operationName: 'deleteActivityLog',
    );
  }

  // Sync operations
  Future<DateTime?> getLastSyncTime() async {
    if (!_enabled) return null;
    return _executeWithRetry(
      () async {
    try {
      final response = await _client
          .from('sync_metadata')
          .select('last_sync')
          .eq('user_id', currentUser?.id ?? '')
          .single();
      
      final lastSyncStr = response['last_sync'] as String?;
      return lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST116') {
            // No sync metadata found, return null
      return null;
    }
          rethrow;
        }
      },
      operationName: 'getLastSyncTime',
    );
  }

  Future<void> updateLastSyncTime(DateTime? syncTime) async {
    if (!_enabled) return;
    return _executeWithRetry(
      () => _client
          .from('sync_metadata')
          .upsert({
            'user_id': currentUser?.id ?? '',
            'last_sync': syncTime?.toIso8601String(),
          }),
      operationName: 'updateLastSyncTime',
    );
  }

  // Batch operations for sync
  Future<void> batchInsertStudents(List<Student> students) async {
    if (!_enabled || students.isEmpty) return;
    
    return _executeWithRetry(
      () async {
      final data = students.map((s) => s.toJson()).toList();
      await _client.from('students').insert(data);
      },
      operationName: 'batchInsertStudents',
    );
  }

  Future<void> batchInsertSubscriptions(List<Subscription> subscriptions) async {
    if (!_enabled || subscriptions.isEmpty) return;
    
    // Validate all subscriptions before batch insert
    for (final subscription in subscriptions) {
      _validateSubscription(subscription);
    }
    
    return _executeWithRetry(
      () async {
      final data = subscriptions.map((s) => s.toJson()).toList();
      await _client.from('subscriptions').insert(data);
      },
      operationName: 'batchInsertSubscriptions',
    );
  }

  Future<void> batchInsertActivityLogs(List<ActivityLog> logs) async {
    if (!_enabled || logs.isEmpty) return;
    
    // Validate all activity logs before batch insert
    for (final activityLog in logs) {
      _validateActivityLog(activityLog);
    }
    
    return _executeWithRetry(
      () async {
      final data = logs.map((l) => l.toJson()).toList();
      await _client.from('activity_logs').insert(data);
      },
      operationName: 'batchInsertActivityLogs',
    );
  }

  // Real-time subscriptions with enhanced error handling
  RealtimeChannel subscribeToStudents(void Function(List<Student>) onUpdate) {
    if (!_enabled) {
      throw StateError('Supabase realtime is disabled in this build');
    }
    final channel = _client.channel('students_channel');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'students',
      callback: (payload) {
        // Trigger a refetch of all students
        getAllStudents().then(onUpdate).catchError((Object error) {
          debugPrint('Error updating students from realtime: $error');
        });
      },
    );
    
    channel.subscribe();
    return channel;
  }

  RealtimeChannel subscribeToSubscriptions(void Function(List<Subscription>) onUpdate) {
    if (!_enabled) {
      throw StateError('Supabase realtime is disabled in this build');
    }
    final channel = _client.channel('subscriptions_channel');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'subscriptions',
      callback: (payload) {
        // Trigger a refetch of all subscriptions
        getAllSubscriptions().then(onUpdate).catchError((Object error) {
          debugPrint('Error updating subscriptions from realtime: $error');
        });
      },
    );
    
    channel.subscribe();
    return channel;
  }

  // App Settings CRUD
  Future<String?> getAppSetting(String key) async {
    if (!_enabled) return null;
    if (key.trim().isEmpty) {
      throw const ValidationException('Setting key cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
        try {
          final response = await _client
              .from('app_settings')
              .select('value')
              .eq('key', key)
              .eq('user_id', currentUser?.id ?? '')
              .single();
          
          return response['value'] as String?;
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST116') {
            // No setting found
            return null;
          }
          rethrow;
        }
      },
      operationName: 'getAppSetting',
    );
  }

  Future<void> setAppSetting(String key, String value, {String? description}) async {
    if (!_enabled) return;
    if (key.trim().isEmpty) {
      throw const ValidationException('Setting key cannot be empty');
    }
    
    return _executeWithRetry(
      () => _client
          .from('app_settings')
          .upsert({
            'key': key,
            'value': value,
            'description': description,
            'user_id': currentUser?.id ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          }),
      operationName: 'setAppSetting',
    );
  }

  Future<void> deleteAppSetting(String key) async {
    if (!_enabled) return;
    if (key.trim().isEmpty) {
      throw const ValidationException('Setting key cannot be empty');
    }
    
    return _executeWithRetry(
      () => _client
          .from('app_settings')
          .delete()
          .eq('key', key)
          .eq('user_id', currentUser?.id ?? ''),
      operationName: 'deleteAppSetting',
    );
  }

  Future<void> clearAllAppSettings() async {
    if (!_enabled) return;
    
    return _executeWithRetry(
      () => _client
          .from('app_settings')
          .delete()
          .eq('user_id', currentUser?.id ?? ''),
      operationName: 'clearAllAppSettings',
    );
  }

  // Additional activity log methods
  Future<List<ActivityLog>> getActivityLogsByType(String type) async {
    if (!_enabled) return <ActivityLog>[];
    if (type.trim().isEmpty) {
      throw const ValidationException('Activity log type cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('activity_logs')
            .select()
            .eq('type', type)
            .order('timestamp', ascending: false)
            .limit(500);
        
        
        
        return (response as List)
            .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getActivityLogsByType',
    );
  }

  Future<List<ActivityLog>> getActivityLogsByEntity(String entityId, String entityType) async {
    if (!_enabled) return <ActivityLog>[];
    if (entityId.trim().isEmpty || entityType.trim().isEmpty) {
      throw const ValidationException('Entity ID and type cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('activity_logs')
            .select()
            .eq('entity_id', entityId)
            .eq('entity_type', entityType)
            .order('timestamp', ascending: false);
        
        
        
        return (response as List)
            .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getActivityLogsByEntity',
    );
  }

  Future<void> deleteActivityLogsByEntity(String entityId, String entityType) async {
    if (!_enabled) return;
    if (entityId.trim().isEmpty || entityType.trim().isEmpty) {
      throw const ValidationException('Entity ID and type cannot be empty');
    }
    
    return _executeWithRetry(
      () => _client
          .from('activity_logs')
          .delete()
          .eq('entity_id', entityId)
          .eq('entity_type', entityType),
      operationName: 'deleteActivityLogsByEntity',
    );
  }

  Future<void> deleteOldActivityLogs(int daysToKeep) async {
    if (!_enabled) return;
    if (daysToKeep < 1) {
      throw const ValidationException('Days to keep must be at least 1');
    }
    
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    return _executeWithRetry(
      () => _client
          .from('activity_logs')
          .delete()
          .lt('timestamp', cutoffDate.toIso8601String()),
      operationName: 'deleteOldActivityLogs',
    );
  }

  Future<void> clearAllActivityLogs() async {
    if (!_enabled) return;
    
    return _executeWithRetry(
      () => _client.from('activity_logs').delete().neq('id', ''),
      operationName: 'clearAllActivityLogs',
    );
  }

  // Additional missing activity log methods
  Future<List<ActivityLog>> getActivityLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!_enabled) return <ActivityLog>[];
    
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('activity_logs')
            .select()
            .gte('timestamp', startDate.toIso8601String())
            .lte('timestamp', endDate.toIso8601String())
            .order('timestamp', ascending: false);
        
        
        
        return (response as List)
            .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getActivityLogsByDateRange',
    );
  }

  Future<List<ActivityLog>> getRecentActivityLogs(int limit) async {
    if (!_enabled) return <ActivityLog>[];
    
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('activity_logs')
            .select()
            .order('timestamp', ascending: false)
            .limit(limit);
        
        
        
        return (response as List)
            .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getRecentActivityLogs',
    );
  }

  Future<List<ActivityLog>> getActivityLogsPaginated(int offset, int limit) async {
    if (!_enabled) return <ActivityLog>[];
    
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('activity_logs')
            .select()
            .order('timestamp', ascending: false)
            .range(offset, offset + limit - 1);
        
        
        
        return (response as List)
            .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getActivityLogsPaginated',
    );
  }

  Future<int> getActivityLogsCount() async {
    if (!_enabled) return 0;
    
    return _executeWithRetry(
      () async {
        final response = await _client
            .from('activity_logs')
            .select('id')
            .count();
        
        return response.count;
      },
      operationName: 'getActivityLogsCount',
    );
  }

  Future<ActivityLog?> getActivityLogById(String id) async {
    if (!_enabled) return null;
    if (id.trim().isEmpty) {
      throw const ValidationException('Activity log ID cannot be empty');
    }
    
    return _executeWithRetry(
      () async {
        try {
          final response = await _client
              .from('activity_logs')
              .select()
              .eq('id', id)
              .single();
          
          return ActivityLog.fromJson(response);
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST116') {
            // No activity log found
            return null;
          }
          rethrow;
        }
      },
      operationName: 'getActivityLogById',
    );
  }

  Stream<List<ActivityLog>> watchRecentActivityLogs(int limit) {
    if (!_enabled) {
      return Stream.value(<ActivityLog>[]);
    }
    
    return _client
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(limit)
        .map((data) => data
            .map((json) => ActivityLog.fromJson(json))
            .toList());
  }

  Stream<List<ActivityLog>> watchAllActivityLogs() {
    if (!_enabled) {
      return Stream.value(<ActivityLog>[]);
    }
    
    return _client
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(1000) // Limit to avoid performance issues
        .map((data) => data
            .map((json) => ActivityLog.fromJson(json))
            .toList());
  }
}