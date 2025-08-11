import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/database/dao/app_settings_dao.dart';
import 'package:library_registration_app/data/repositories/activity_log_repository_impl.dart';
import 'package:library_registration_app/data/repositories/student_repository_impl.dart';
import 'package:library_registration_app/data/repositories/subscription_repository_impl.dart';
import 'package:library_registration_app/data/services/backup_service.dart';
import 'package:library_registration_app/domain/repositories/activity_log_repository.dart';
import 'package:library_registration_app/domain/repositories/student_repository.dart';
import 'package:library_registration_app/domain/repositories/subscription_repository.dart';

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// DAO providers
final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  final database = ref.watch(databaseProvider);
  return database.appSettingsDao;
});

// Repository providers
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return StudentRepositoryImpl(database);
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SubscriptionRepositoryImpl(database);
});

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ActivityLogRepositoryImpl(database);
});

// Backup service provider
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupService(
    db: db,
    appSettingsDao: db.appSettingsDao,
    studentsDao: db.studentsDao,
    subscriptionsDao: db.subscriptionsDao,
    activityLogsDao: db.activityLogsDao,
  );
});
