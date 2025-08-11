import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/database/tables/activity_logs_table.dart';

part 'activity_logs_dao.g.dart';

@DriftAccessor(tables: [ActivityLogsTable])
class ActivityLogsDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityLogsDaoMixin {
  ActivityLogsDao(super.db);

  // Get all activity logs
  Future<List<ActivityLogData>> getAllActivityLogs() {
    return (select(activityLogsTable)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.timestamp, mode: OrderingMode.desc),
        ]))
        .get();
  }

  // Get activity logs with pagination
  Future<List<ActivityLogData>> getActivityLogsWithPagination({
    required int limit,
    required int offset,
  }) {
    return (select(activityLogsTable)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  // Get activity logs by entity type
  Future<List<ActivityLogData>> getActivityLogsByEntityType(String entityType) {
    return (select(activityLogsTable)
          ..where((tbl) => tbl.entityType.equals(entityType))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get activity logs by entity ID
  Future<List<ActivityLogData>> getActivityLogsByEntityId(String entityId) {
    return (select(activityLogsTable)
          ..where((tbl) => tbl.entityId.equals(entityId))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get activity logs by action
  Future<List<ActivityLogData>> getActivityLogsByAction(String action) {
    return (select(activityLogsTable)
          ..where((tbl) => tbl.action.equals(action))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get activity logs within date range
  Future<List<ActivityLogData>> getActivityLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return (select(activityLogsTable)
          ..where((tbl) => tbl.timestamp.isBetweenValues(startDate, endDate))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get recent activity logs
  Future<List<ActivityLogData>> getRecentActivityLogs({int limit = 50}) {
    return (select(activityLogsTable)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .get();
  }

  // Watch all activity logs (for real-time updates)
  Stream<List<ActivityLogData>> watchAllActivityLogs() {
    return (select(activityLogsTable)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.timestamp, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // Watch recent activity logs with limit
  Stream<List<ActivityLogData>> watchRecentActivityLogs(int limit) {
    return (select(activityLogsTable)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .watch();
  }

  // Get activity logs for today
  Future<List<ActivityLogData>> getTodayActivityLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getActivityLogsByDateRange(startDate: startOfDay, endDate: endOfDay);
  }

  // Get activity statistics
  Future<Map<String, int>> getActivityStatistics() async {
    final totalCount = await _getTotalCount();
    final todayCount = await _getTodayCount();
    final thisWeekCount = await _getThisWeekCount();
    final thisMonthCount = await _getThisMonthCount();

    return {
      'total': totalCount,
      'today': todayCount,
      'thisWeek': thisWeekCount,
      'thisMonth': thisMonthCount,
    };
  }

  Future<int> _getTotalCount() async {
    final countExp = countAll();
    final query = selectOnly(activityLogsTable)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<int> _getTodayCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final countExp = countAll();
    final query = selectOnly(activityLogsTable)
      ..addColumns([countExp])
      ..where(
        activityLogsTable.timestamp.isBetweenValues(startOfDay, endOfDay),
      );

    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<int> _getThisWeekCount() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    final countExp = countAll();
    final query = selectOnly(activityLogsTable)
      ..addColumns([countExp])
      ..where(activityLogsTable.timestamp.isBiggerOrEqualValue(startOfWeekDay));

    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<int> _getThisMonthCount() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);

    final countExp = countAll();
    final query = selectOnly(activityLogsTable)
      ..addColumns([countExp])
      ..where(activityLogsTable.timestamp.isBiggerOrEqualValue(startOfMonth));

    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // Get activity statistics by entity type
  Future<Map<String, int>> getActivityStatisticsByEntityType() async {
    final results = <String, int>{};

    final entityTypes = [
      'student',
      'subscription',
      'backup',
      'settings',
      'auth',
      'system',
    ];

    for (final entityType in entityTypes) {
      final countExp = countAll();
      final query = selectOnly(activityLogsTable)
        ..addColumns([countExp])
        ..where(activityLogsTable.entityType.equals(entityType));

      final result = await query.getSingle();
      results[entityType] = result.read(countExp) ?? 0;
    }

    return results;
  }

  // Insert new activity log
  Future<int> insertActivityLog(ActivityLogsTableCompanion activityLog) {
    return into(activityLogsTable).insert(activityLog);
  }

  // Log activity (convenience method)
  Future<int> logActivity({
    required String id,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? details,
    String? userId,
  }) {
    return insertActivityLog(
      ActivityLogsTableCompanion(
        id: Value(id),
        action: Value(action),
        entityType: Value(entityType),
        entityId: Value(entityId),
        details: Value(details?.toString()),
        timestamp: Value(DateTime.now()),
        userId: Value(userId),
      ),
    );
  }

  // Delete old activity logs (cleanup)
  Future<int> deleteOldActivityLogs({required int daysToKeep}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    final deletedRows = await (delete(
      activityLogsTable,
    )..where((tbl) => tbl.timestamp.isSmallerThanValue(cutoffDate))).go();

    return deletedRows;
  }

  // Delete activity logs by entity ID
  Future<int> deleteActivityLogsByEntityId(String entityId) async {
    final deletedRows = await (delete(
      activityLogsTable,
    )..where((tbl) => tbl.entityId.equals(entityId))).go();

    return deletedRows;
  }

  // Search activity logs
  Future<List<ActivityLogData>> searchActivityLogs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';

    return (select(activityLogsTable)
          ..where(
            (tbl) =>
                tbl.action.lower().like(searchTerm) |
                tbl.entityType.lower().like(searchTerm) |
                (tbl.entityId.isNotNull() &
                    tbl.entityId.lower().like(searchTerm)) |
                (tbl.details.isNotNull() &
                    tbl.details.lower().like(searchTerm)),
          )
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get activity log by ID
  Future<ActivityLogData?> getActivityLogById(String id) {
    return (select(
      activityLogsTable,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  // Clear all activity logs
  Future<int> clearAllActivityLogs() async {
    return delete(activityLogsTable).go();
  }

  // Get activity logs count
  Future<int> getActivityLogsCount() async {
    final countExp = countAll();
    final query = selectOnly(activityLogsTable)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // Delete activity log by ID
  Future<int> deleteActivityLog(String id) async {
    return (delete(activityLogsTable)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<List<ActivityLogData>> getActivityLogsByEntity(
    String entityId,
    String entityType,
  ) {
    return (select(activityLogsTable)
          ..where(
            (tbl) =>
                tbl.entityId.equals(entityId) &
                tbl.entityType.equals(entityType),
          )
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getActivityLogsByType(String activityType) {
    return (select(activityLogsTable)
          ..where((tbl) => tbl.action.equals(activityType))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getActivityLogsPaginated(
    int offset,
    int limit,
  ) {
    return (select(activityLogsTable)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit, offset: offset))
        .get();
  }
}
