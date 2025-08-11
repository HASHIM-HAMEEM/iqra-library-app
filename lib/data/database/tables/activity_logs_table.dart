import 'package:drift/drift.dart';

@DataClassName('ActivityLogData')
class ActivityLogsTable extends Table {
  @override
  String get tableName => 'activity_logs';

  // Primary key - UUID v4
  TextColumn get id => text()();

  // Action details
  TextColumn get action => text().withLength(min: 1, max: 100)();
  TextColumn get entityType => text().withLength(min: 1, max: 50)();
  TextColumn get entityId => text().nullable()();

  // Additional context data (JSON format)
  TextColumn get details => text().nullable()();

  // Timestamp
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  // User context (for future multi-admin support)
  TextColumn get userId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // Action validation

    // Entity type validation
    'CHECK (LENGTH(TRIM(entity_type)) > 0)',
    // Common entity types
    "CHECK (entity_type IN ('student', 'subscription', 'backup', 'settings', 'auth', 'system'))",
  ];
}
