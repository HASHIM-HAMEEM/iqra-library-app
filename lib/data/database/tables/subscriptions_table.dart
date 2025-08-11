import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/tables/students_table.dart';

@DataClassName('SubscriptionData')
class SubscriptionsTable extends Table {
  @override
  String get tableName => 'subscriptions';

  // Primary key - UUID v4
  TextColumn get id => text()();

  // Foreign key to students table
  TextColumn get studentId => text().references(StudentsTable, #id)();

  // Subscription details
  TextColumn get planName => text().withLength(min: 1, max: 100)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  // Pricing
  RealColumn get amount => real().withDefault(const Constant(0))();

  // Status: active, expired, cancelled, pending
  TextColumn get status => text().withLength(min: 1, max: 20)();

  // Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // Status validation
    "CHECK (status IN ('active', 'expired', 'cancelled', 'pending'))",
    // Date validation - end date should be after start date if provided
    'CHECK (end_date IS NULL OR end_date > start_date)',
    // Plan name validation
    'CHECK (LENGTH(TRIM(plan_name)) > 0)',
    // Amount validation
    'CHECK (amount >= 0)',
  ];
}
