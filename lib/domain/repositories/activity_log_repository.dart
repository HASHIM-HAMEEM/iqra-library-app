import 'package:library_registration_app/domain/entities/activity_log.dart';

abstract class ActivityLogRepository {
  Future<List<ActivityLog>> getAllActivityLogs();
  Future<List<ActivityLog>> getActivityLogsByType(ActivityType type);
  Future<List<ActivityLog>> getActivityLogsByEntity(
    String entityId,
    String entityType,
  );
  Future<List<ActivityLog>> getActivityLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<ActivityLog>> getRecentActivityLogs(int limit);
  Future<List<ActivityLog>> getActivityLogsPaginated(int offset, int limit);
  Future<int> getActivityLogsCount();
  Future<ActivityLog?> getActivityLogById(String id);

  Future<String> createActivityLog(ActivityLog activityLog);
  Future<void> deleteActivityLog(String id);
  Future<void> deleteOldActivityLogs(int daysToKeep);
  Future<void> clearAllActivityLogs();

  Stream<List<ActivityLog>> watchRecentActivityLogs(int limit);
  Stream<List<ActivityLog>> watchAllActivityLogs();
}
