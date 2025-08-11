/// App configuration constants and settings
class AppConfig {
  // App Information
  static const String appName = 'IQRA';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'IQRA — Offline-first library management with a modern, assistant-style interface';

  // Database Configuration
  static const String databaseName = 'library_registration.db';
  static const int databaseVersion = 1;

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
}
