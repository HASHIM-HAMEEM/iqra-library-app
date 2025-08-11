import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/models/activity_log_model.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/domain/repositories/activity_log_repository.dart';
import 'package:uuid/uuid.dart';

class ActivityLogRepositoryImpl implements ActivityLogRepository {
  ActivityLogRepositoryImpl(this._database);
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<ActivityLog>> getAllActivityLogs() async {
    final logs = await _database.activityLogsDao.getAllActivityLogs();
    return logs
        .map((log) => ActivityLogModel.fromDrift(log).toEntity())
        .toList();
  }

  @override
  Future<List<ActivityLog>> getActivityLogsByType(ActivityType type) async {
    final logs = await _database.activityLogsDao.getActivityLogsByType(
      type.databaseValue,
    );
    return logs
        .map((log) => ActivityLogModel.fromDrift(log).toEntity())
        .toList();
  }

  @override
  Future<List<ActivityLog>> getActivityLogsByEntity(
    String entityId,
    String entityType,
  ) async {
    final logs = await _database.activityLogsDao.getActivityLogsByEntity(
      entityId,
      entityType,
    );
    return logs
        .map((log) => ActivityLogModel.fromDrift(log).toEntity())
        .toList();
  }

  @override
  Future<List<ActivityLog>> getActivityLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final logs = await _database.activityLogsDao.getActivityLogsByDateRange(
      startDate: startDate,
      endDate: endDate,
    );
    return logs
        .map((log) => ActivityLogModel.fromDrift(log).toEntity())
        .toList();
  }

  @override
  Future<List<ActivityLog>> getRecentActivityLogs(int limit) async {
    final logs = await _database.activityLogsDao.getRecentActivityLogs(
      limit: limit,
    );
    return logs
        .map((log) => ActivityLogModel.fromDrift(log).toEntity())
        .toList();
  }

  @override
  Future<List<ActivityLog>> getActivityLogsPaginated(
    int offset,
    int limit,
  ) async {
    final logs = await _database.activityLogsDao.getActivityLogsPaginated(
      offset,
      limit,
    );
    return logs
        .map((log) => ActivityLogModel.fromDrift(log).toEntity())
        .toList();
  }

  @override
  Future<int> getActivityLogsCount() async {
    return _database.activityLogsDao.getActivityLogsCount();
  }

  @override
  Future<ActivityLog?> getActivityLogById(String id) async {
    final log = await _database.activityLogsDao.getActivityLogById(id);
    return log != null ? ActivityLogModel.fromDrift(log).toEntity() : null;
  }

  @override
  Future<String> createActivityLog(ActivityLog activityLog) async {
    final id = _uuid.v4();

    final logModel = ActivityLogModel(
      id: id,
      activityType: activityLog.activityType,
      description: activityLog.description,
      entityId: activityLog.entityId,
      entityType: activityLog.entityType,
      metadata: activityLog.metadata,
      timestamp: activityLog.timestamp,
    );

    await _database.activityLogsDao.insertActivityLog(logModel.toDrift());
    return id;
  }

  @override
  Future<void> deleteActivityLog(String id) async {
    await _database.activityLogsDao.deleteActivityLog(id);
  }

  @override
  Future<void> deleteOldActivityLogs(int daysToKeep) async {
    await _database.activityLogsDao.deleteOldActivityLogs(
      daysToKeep: daysToKeep,
    );
  }

  @override
  Future<void> clearAllActivityLogs() async {
    await _database.activityLogsDao.clearAllActivityLogs();
  }

  @override
  Stream<List<ActivityLog>> watchRecentActivityLogs(int limit) {
    return _database.activityLogsDao
        .watchRecentActivityLogs(limit)
        .map(
          (logs) => logs
              .map((log) => ActivityLogModel.fromDrift(log).toEntity())
              .toList(),
        );
  }

  @override
  Stream<List<ActivityLog>> watchAllActivityLogs() {
    return _database.activityLogsDao
        .watchRecentActivityLogs(50)
        .map(
          (logs) => logs
              .map((log) => ActivityLogModel.fromDrift(log).toEntity())
              .toList(),
        );
  }
}
