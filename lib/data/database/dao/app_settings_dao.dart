import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/database/tables/app_settings_table.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettingsTable])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  // Get all settings
  Future<List<AppSettingData>> getAllSettings() {
    return (select(
      appSettingsTable,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.key)])).get();
  }

  // Get setting by key
  Future<AppSettingData?> getSettingByKey(String key) {
    return (select(
      appSettingsTable,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
  }

  // Get setting value by key
  Future<String?> getSettingValue(String key) async {
    final setting = await getSettingByKey(key);
    return setting?.value;
  }

  // Get string setting
  Future<String?> getStringSetting(String key) async {
    final setting = await getSettingByKey(key);
    if (setting?.type == 'string') {
      return setting?.value;
    }
    return null;
  }

  // Get int setting
  Future<int?> getIntSetting(String key) async {
    final setting = await getSettingByKey(key);
    if (setting?.type == 'int') {
      return int.tryParse(setting?.value ?? '');
    }
    return null;
  }

  // Get double setting
  Future<double?> getDoubleSetting(String key) async {
    final setting = await getSettingByKey(key);
    if (setting?.type == 'double') {
      return double.tryParse(setting?.value ?? '');
    }
    return null;
  }

  // Get bool setting
  Future<bool?> getBoolSetting(String key) async {
    final setting = await getSettingByKey(key);
    if (setting?.type == 'bool') {
      return setting?.value.toLowerCase() == 'true';
    }
    return null;
  }

  // Get settings by type
  Future<List<AppSettingData>> getSettingsByType(String type) {
    return (select(appSettingsTable)
          ..where((tbl) => tbl.type.equals(type))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.key)]))
        .get();
  }

  // Insert or update setting
  Future<void> upsertSetting(AppSettingsTableCompanion setting) async {
    await into(appSettingsTable).insertOnConflictUpdate(setting);
  }

  // Set string setting
  Future<void> setStringSetting(
    String key,
    String value, {
    String? description,
  }) async {
    await upsertSetting(
      AppSettingsTableCompanion(
        key: Value(key),
        value: Value(value),
        type: const Value('string'),
        description: Value(description),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Set int setting
  Future<void> setIntSetting(
    String key,
    int value, {
    String? description,
  }) async {
    await upsertSetting(
      AppSettingsTableCompanion(
        key: Value(key),
        value: Value(value.toString()),
        type: const Value('int'),
        description: Value(description),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Set double setting
  Future<void> setDoubleSetting(
    String key,
    double value, {
    String? description,
  }) async {
    await upsertSetting(
      AppSettingsTableCompanion(
        key: Value(key),
        value: Value(value.toString()),
        type: const Value('double'),
        description: Value(description),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Set bool setting
  Future<void> setBoolSetting(
    String key,
    bool value, {
    String? description,
  }) async {
    await upsertSetting(
      AppSettingsTableCompanion(
        key: Value(key),
        value: Value(value.toString()),
        type: const Value('bool'),
        description: Value(description),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Set JSON setting
  Future<void> setJsonSetting(
    String key,
    String jsonValue, {
    String? description,
  }) async {
    await upsertSetting(
      AppSettingsTableCompanion(
        key: Value(key),
        value: Value(jsonValue),
        type: const Value('json'),
        description: Value(description),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Delete setting
  Future<bool> deleteSetting(String key) async {
    final deletedRows = await (delete(
      appSettingsTable,
    )..where((tbl) => tbl.key.equals(key))).go();
    return deletedRows > 0;
  }

  // Check if setting exists
  Future<bool> settingExists(String key) async {
    final setting = await getSettingByKey(key);
    return setting != null;
  }

  // Insert default settings
  Future<void> insertDefaultSettings() async {
    final defaultSettings = [
      AppSettingsTableCompanion(
        key: const Value('app_version'),
        value: const Value('1.0.0'),
        type: const Value('string'),
        description: const Value('Application version'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('database_version'),
        value: const Value('1'),
        type: const Value('int'),
        description: const Value('Database schema version'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('auto_backup_enabled'),
        value: const Value('true'),
        type: const Value('bool'),
        description: const Value('Enable automatic backups'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('backup_frequency_days'),
        value: const Value('7'),
        type: const Value('int'),
        description: const Value('Backup frequency in days'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('theme_mode'),
        value: const Value('system'),
        type: const Value('string'),
        description: const Value('Theme mode: light, dark, or system'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('biometric_auth_enabled'),
        value: const Value('false'),
        type: const Value('bool'),
        description: const Value('Enable biometric authentication'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('session_timeout_minutes'),
        value: const Value('30'),
        type: const Value('int'),
        description: const Value('Session timeout in minutes'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('default_subscription_plan'),
        value: const Value('Basic'),
        type: const Value('string'),
        description: const Value('Default subscription plan name'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('library_name'),
        value: const Value('Library Registration System'),
        type: const Value('string'),
        description: const Value('Name of the library'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      AppSettingsTableCompanion(
        key: const Value('admin_email'),
        value: const Value('admin@library.com'),
        type: const Value('string'),
        description: const Value('Administrator email address'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    ];

    for (final setting in defaultSettings) {
      final exists = await settingExists(setting.key.value);
      if (!exists) {
        await into(appSettingsTable).insert(setting);
      }
    }
  }

  // Reset settings to default
  Future<void> resetToDefaults() async {
    await delete(appSettingsTable).go();
    await insertDefaultSettings();
  }

  // Export settings as Map
  Future<Map<String, dynamic>> exportSettings() async {
    final settings = await getAllSettings();
    final result = <String, dynamic>{};

    for (final setting in settings) {
      switch (setting.type) {
        case 'int':
          result[setting.key] = int.tryParse(setting.value) ?? 0;
        case 'double':
          result[setting.key] = double.tryParse(setting.value) ?? 0.0;
        case 'bool':
          result[setting.key] = setting.value.toLowerCase() == 'true';
        default:
          result[setting.key] = setting.value;
      }
    }

    return result;
  }

  // Import settings from Map
  Future<void> importSettings(Map<String, dynamic> settingsMap) async {
    for (final entry in settingsMap.entries) {
      final key = entry.key;
      final value = entry.value;

      String type;
      String stringValue;

      if (value is int) {
        type = 'int';
        stringValue = value.toString();
      } else if (value is double) {
        type = 'double';
        stringValue = value.toString();
      } else if (value is bool) {
        type = 'bool';
        stringValue = value.toString();
      } else {
        type = 'string';
        stringValue = value.toString();
      }

      await upsertSetting(
        AppSettingsTableCompanion(
          key: Value(key),
          value: Value(stringValue),
          type: Value(type),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
