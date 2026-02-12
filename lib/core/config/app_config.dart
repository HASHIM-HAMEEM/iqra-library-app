import 'dart:convert' show base64Url, jsonDecode, utf8;

/// App configuration constants and settings
class AppConfig {
  // App Information
  static const String appName = 'IQRA';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'IQRA — Offline-first library management with a modern, assistant-style interface';

  // Database Configuration (legacy local DB removed; Supabase is source of truth)

  // Security Configuration
  static const String encryptionKeyAlias = 'library_app_key';
  static const int pbkdf2Iterations = 100000;
  static const int sessionTimeoutMinutes = 30;

  // UI Configuration
  static const double defaultPadding = 16;
  static const double cardBorderRadius = 12;
  static const double buttonBorderRadius = 8;
  static const int animationDurationMs = 300;

  // Chat Interface Configuration
  static const int maxChatHistoryItems = 100;
  static const int typingIndicatorDelayMs = 1000;

  // Backup Configuration
  static const String backupFilePrefix = 'library_backup';
  static const String csvFilePrefix = 'library_export';
  static const int autoBackupIntervalDays = 7;

  // Validation Rules
  static const int minPasswordLength = 6;
  static const int maxStudentNameLength = 50;
  static const int maxAddressLength = 200;

  // Performance Configuration
  static const int maxStudentsPerPage = 50;
  static const int searchDebounceMs = 500;

  // Feature Flags
  static const bool enableBiometricAuth = true;
  // Developer diagnostics overlay & extra logs
  static const bool developerMode = false; // set true in dev builds or via remote config
  // When true, allow Android to fall back to device credentials (PIN/Pattern/Password)
  // if biometrics are unavailable. Keep false to enforce biometrics only.
  static const bool allowDeviceCredentialFallback = false;
  static const bool enableVoiceInput = true;
  static const bool enableDataExport = true;
  static const bool enableAutoBackup = true;

  // Supabase Configuration
  // Project ref from anon key: rqghiwjhizmlvdagicnw
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rqghiwjhizmlvdagicnw.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxZ2hpd2poaXptbHZkYWdpY253Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMTEwMjUsImV4cCI6MjA3MDU4NzAyNX0.zm7SWW-6d_STzZ97L5D-bWdJLmAdgsX_yZV_C7ArjY4',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static List<String> get supabaseConfigIssues {
    final issues = <String>[];
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    if (url.isEmpty) issues.add('Missing SUPABASE_URL');
    if (key.isEmpty) issues.add('Missing SUPABASE_ANON_KEY');
    if (url.isNotEmpty && !url.startsWith('https://')) {
      issues.add('SUPABASE_URL must start with https://');
    }

    // Supabase supports both legacy JWT keys and the newer `sb_publishable_*`
    // keys. We accept either, but we try to detect and block service-role keys.
    if (key.startsWith('sb_secret_')) {
      issues.add(
        'SUPABASE_ANON_KEY must be a publishable/anon key (sb_publishable_* or anon JWT), not an sb_secret_* key',
      );
      return issues;
    }

    // Best-effort detection for JWT service_role keys.
    // (If it isn't a JWT, we just accept it as-is.)
    final parts = key.split('.');
    if (parts.length == 3) {
      try {
        final payload = _decodeJwtPayload(parts[1]);
        final role = payload['role'];
        if (role == 'service_role') {
          issues.add(
            'SUPABASE_ANON_KEY appears to be a service_role key. Use the anon/publishable key instead.',
          );
        }
      } catch (_) {
        // Ignore decoding errors; key may be a non-JWT publishable key.
      }
    }
    return issues;
  }

  static Map<String, dynamic> _decodeJwtPayload(String b64Url) {
    // Normalize base64url padding
    final normalized = b64Url.padRight(b64Url.length + ((4 - b64Url.length % 4) % 4), '=');
    final bytes = base64Url.decode(normalized);
    final jsonStr = utf8.decode(bytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  // Student ID Card configuration
  // NOTE: In production, keep signing in trusted backend when possible.
  static const String idCardVerificationBaseUrl = String.fromEnvironment(
    'ID_CARD_VERIFY_URL',
    defaultValue: '',
  );
}
