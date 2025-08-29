import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/data/repositories/activity_log_repository_impl.dart';
import 'package:library_registration_app/data/repositories/student_repository_impl.dart';
import 'package:library_registration_app/data/repositories/subscription_repository_impl.dart';
import 'package:library_registration_app/core/config/app_config.dart';
import 'package:library_registration_app/core/services/cache_service.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:library_registration_app/data/services/app_settings_service.dart';
import 'package:library_registration_app/domain/repositories/activity_log_repository.dart';
import 'package:library_registration_app/domain/repositories/student_repository.dart';
import 'package:library_registration_app/domain/repositories/subscription_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// App Settings Service provider
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  // Local-only settings; no DB dependency
  return AppSettingsService();
});

// Legacy provider for backward compatibility
final appSettingsDaoProvider = Provider<AppSettingsService>((ref) {
  return ref.watch(appSettingsServiceProvider);
});

// Repository providers
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return StudentRepositoryImpl(supabase);
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return SubscriptionRepositoryImpl(supabase);
});

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return ActivityLogRepositoryImpl(supabase);
});



// Supabase service provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  // Use the initialized Supabase instance with session persistence
  final bool hasConfig =
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty;

  if (!hasConfig) {
    // Disabled service when not configured
    final disabledClient = SupabaseClient('https://disabled.local', 'disabled');
    return SupabaseService(client: disabledClient, enabled: false);
  }

  // Use the initialized Supabase client with session persistence
  try {
    final client = Supabase.instance.client;
    return SupabaseService(client: client, enabled: true, cache: CacheService());
  } catch (e) {
    // Fallback to direct client creation if initialization failed
    final client = SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);
    return SupabaseService(client: client, enabled: true, cache: CacheService());
  }
});

// Removed migration service provider - no longer needed with Supabase-only implementation
