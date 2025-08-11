import 'package:drift/drift.dart';

@DataClassName('StudentData')
class StudentsTable extends Table {
  @override
  String get tableName => 'students';

  // Primary key - UUID v4
  TextColumn get id => text()();

  // Personal information
  TextColumn get firstName => text().withLength(min: 1, max: 50)();
  TextColumn get lastName => text().withLength(min: 1, max: 50)();
  // Nullable seat number (alphanumeric)
  TextColumn get seatNumber => text().nullable()();
  DateTimeColumn get dateOfBirth => dateTime()();

  // Contact information
  TextColumn get email => text().unique()();
  TextColumn get phone => text().withLength(min: 10, max: 20).nullable()();
  TextColumn get address => text().withLength(max: 200).nullable()();

  // Subscription information
  TextColumn get subscriptionPlan => text().nullable()();
  DateTimeColumn get subscriptionStartDate => dateTime().nullable()();
  DateTimeColumn get subscriptionEndDate => dateTime().nullable()();
  RealColumn get subscriptionAmount => real().nullable()();
  TextColumn get subscriptionStatus => text().nullable()();

  // Optional profile image path
  TextColumn get profileImagePath => text().nullable()();

  // Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Soft delete flag
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // Email format validation
    "CHECK (email LIKE '%@%.%')",
    // Phone number validation (basic) - only if not null
    'CHECK (phone IS NULL OR LENGTH(phone) >= 10)',
    // Name validation
    'CHECK (LENGTH(TRIM(first_name)) > 0)',
    'CHECK (LENGTH(TRIM(last_name)) > 0)',
  ];
}
