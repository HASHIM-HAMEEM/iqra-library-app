import 'package:drift/drift.dart';

@DataClassName('AppSettingData')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  // Primary key - setting key
  TextColumn get key => text().withLength(min: 1, max: 100)();

  // Setting value (stored as text, can be JSON for complex data)
  TextColumn get value => text()();

  // Setting type for validation and parsing
  TextColumn get type => text().withLength(min: 1, max: 20)();

  // Optional description
  TextColumn get description => text().nullable()();

  // Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};

  @override
  List<String> get customConstraints => [
    // Key validation

    // Type validation
    "CHECK (type IN ('string', 'int', 'double', 'bool', 'json'))",
  ];
}
