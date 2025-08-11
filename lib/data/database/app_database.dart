import 'package:drift/drift.dart';
// Conditional imports for different platforms
import 'package:library_registration_app/data/database/connection/connection.dart'
    if (dart.library.io) 'connection/native.dart'
    if (dart.library.html) 'connection/web.dart';
import 'package:library_registration_app/data/database/dao/activity_logs_dao.dart';
import 'package:library_registration_app/data/database/dao/app_settings_dao.dart';
import 'package:library_registration_app/data/database/dao/students_dao.dart';
import 'package:library_registration_app/data/database/dao/subscriptions_dao.dart';
import 'package:library_registration_app/data/database/tables/activity_logs_table.dart';
import 'package:library_registration_app/data/database/tables/app_settings_table.dart';
import 'package:library_registration_app/data/database/tables/students_table.dart';
import 'package:library_registration_app/data/database/tables/subscriptions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    StudentsTable,
    SubscriptionsTable,
    ActivityLogsTable,
    AppSettingsTable,
  ],
  daos: [StudentsDao, SubscriptionsDao, ActivityLogsDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Insert default app settings
        await appSettingsDao.insertDefaultSettings();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v2: Add subscription-related columns to students table
        if (from < 2) {
          await m.addColumn(studentsTable, studentsTable.subscriptionPlan);
          await m.addColumn(studentsTable, studentsTable.subscriptionStartDate);
          await m.addColumn(studentsTable, studentsTable.subscriptionEndDate);
          await m.addColumn(studentsTable, studentsTable.subscriptionAmount);
          await m.addColumn(studentsTable, studentsTable.subscriptionStatus);
        }
        // v3: Add nullable seatNumber column to students table
        if (from < 3) {
          await m.addColumn(studentsTable, studentsTable.seatNumber);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final executor = await openConnection();
    return executor;
  });
}
