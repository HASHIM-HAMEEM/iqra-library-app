import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local-only App Settings Service (no database calls)
/// Uses FlutterSecureStorage to persist small settings on device.
class AppSettingsService {
  AppSettingsService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // Namespacing all keys avoids clobbering other storage entries
  static const String _keyPrefix = 'app_settings:';
  final FlutterSecureStorage _storage;

  String _k(String key) => '$_keyPrefix$key';

  /// Get a string setting value
  Future<String?> getStringSetting(String key) async {
    try {
      return await _storage.read(key: _k(key));
    } catch (_) {
      return null;
    }
  }

  /// Set a string setting value
  Future<void> setStringSetting(
    String key,
    String value, {
    String? description, // kept for API compatibility; unused
  }) async {
    try {
      await _storage.write(key: _k(key), value: value);
    } catch (_) {
      // Silently ignore storage errors for non-critical settings
    }
  }

  /// Get an integer setting value
  Future<int?> getIntSetting(String key) async {
    final stringValue = await getStringSetting(key);
    if (stringValue == null) return null;
    try {
      return int.parse(stringValue);
    } catch (_) {
      return null;
    }
  }

  /// Set an integer setting value
  Future<void> setIntSetting(
    String key,
    int value, {
    String? description,
  }) async {
    await setStringSetting(key, value.toString(), description: description);
  }

  /// Get a boolean setting value
  Future<bool?> getBoolSetting(String key) async {
    final stringValue = await getStringSetting(key);
    if (stringValue == null) return null;
    return stringValue.toLowerCase() == 'true';
  }

  /// Set a boolean setting value
  Future<void> setBoolSetting(
    String key,
    bool value, {
    String? description,
  }) async {
    await setStringSetting(key, value.toString(), description: description);
  }

  /// Delete a setting
  Future<void> deleteSetting(String key) async {
    try {
      await _storage.delete(key: _k(key));
    } catch (_) {
      // ignore
    }
  }

  /// Reset all app settings managed by this service (prefix-based)
  Future<void> resetToDefaults() async {
    try {
      final all = await _storage.readAll();
      for (final entry in all.entries) {
        if (entry.key.startsWith(_keyPrefix)) {
          await _storage.delete(key: entry.key);
        }
      }
    } catch (_) {
      // ignore
    }
  }
}