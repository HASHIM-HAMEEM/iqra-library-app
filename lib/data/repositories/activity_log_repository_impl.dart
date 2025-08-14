// import 'package:library_registration_app/data/models/activity_log_model.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/domain/repositories/activity_log_repository.dart';
// import 'package:uuid/uuid.dart';

class ActivityLogRepositoryImpl implements ActivityLogRepository {
  ActivityLogRepositoryImpl(this._supabase);
  final SupabaseService _supabase;
  // final Uuid _uuid = const Uuid();

  @override
  Future<List<ActivityLog>> getAllActivityLogs() async {
    return await _supabase.getAllActivityLogs();
  }

  @override
  Future<List<ActivityLog>> getActivityLogsByType(ActivityType type) async {
    return await _supabase.getActivityLogsByType(type.databaseValue);
  }

  @override
  Future<List<ActivityLog>> getActivityLogsByEntity(
    String entityId,
    String entityType,
  ) async {
    return await _supabase.getActivityLogsByEntity(entityId, entityType);
  }

  @override
  Future<List<ActivityLog>> getActivityLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _supabase.getActivityLogsByDateRange(startDate, endDate);
  }

  @override
  Future<List<ActivityLog>> getRecentActivityLogs(int limit) async {
    return await _supabase.getRecentActivityLogs(limit);
  }

  @override
  Future<List<ActivityLog>> getActivityLogsPaginated(
    int offset,
    int limit,
  ) async {
    return await _supabase.getActivityLogsPaginated(offset, limit);
  }

  @override
  Future<int> getActivityLogsCount() async {
    return await _supabase.getActivityLogsCount();
  }

  @override
  Future<ActivityLog?> getActivityLogById(String id) async {
    return await _supabase.getActivityLogById(id);
  }

  @override
  Future<String> createActivityLog(ActivityLog activityLog) async {
    final createdLog = await _supabase.createActivityLog(activityLog);
    return createdLog.id;
  }

  @override
  Future<void> deleteActivityLog(String id) async {
    await _supabase.deleteActivityLog(id);
  }

  @override
  Future<void> deleteOldActivityLogs(int daysToKeep) async {
    await _supabase.deleteOldActivityLogs(daysToKeep);
  }

  @override
  Future<void> clearAllActivityLogs() async {
    await _supabase.clearAllActivityLogs();
  }

  @override
  Stream<List<ActivityLog>> watchRecentActivityLogs(int limit) {
    return _supabase.watchRecentActivityLogs(limit);
  }

  @override
  Stream<List<ActivityLog>> watchAllActivityLogs() {
    return _supabase.watchAllActivityLogs();
  }
}
