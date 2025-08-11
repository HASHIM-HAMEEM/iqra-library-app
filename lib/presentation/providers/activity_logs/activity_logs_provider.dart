import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';

// All activity logs provider
final activityLogsProvider = StreamProvider<List<ActivityLog>>((ref) {
  final repository = ref.watch(activityLogRepositoryProvider);
  return repository.watchAllActivityLogs();
});

// Recent activity logs provider
final recentActivityLogsProvider =
    StreamProvider.family<List<ActivityLog>, int>((ref, limit) {
      final repository = ref.watch(activityLogRepositoryProvider);
      return repository.watchRecentActivityLogs(limit);
    });

// Activity log by ID provider
final activityLogByIdProvider = FutureProvider.family<ActivityLog?, String>((
  ref,
  id,
) {
  final repository = ref.watch(activityLogRepositoryProvider);
  return repository.getActivityLogById(id);
});

// Activity logs by type provider
final activityLogsByTypeProvider =
    FutureProvider.family<List<ActivityLog>, ActivityType>((ref, type) {
      final repository = ref.watch(activityLogRepositoryProvider);
      return repository.getActivityLogsByType(type);
    });

// Activity logs by entity provider
final activityLogsByEntityProvider =
    FutureProvider.family<
      List<ActivityLog>,
      ({String entityId, String entityType})
    >((ref, params) {
      final repository = ref.watch(activityLogRepositoryProvider);
      return repository.getActivityLogsByEntity(
        params.entityId,
        params.entityType,
      );
    });

// Activity logs by date range provider
final activityLogsByDateRangeProvider =
    FutureProvider.family<
      List<ActivityLog>,
      ({DateTime startDate, DateTime endDate})
    >((ref, params) {
      final repository = ref.watch(activityLogRepositoryProvider);
      return repository.getActivityLogsByDateRange(
        params.startDate,
        params.endDate,
      );
    });

// Activity logs count provider
final activityLogsCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(activityLogRepositoryProvider);
  return repository.getActivityLogsCount();
});

// Activity logs paginated provider
final activityLogsPaginatedProvider =
    FutureProvider.family<List<ActivityLog>, ({int offset, int limit})>((
      ref,
      params,
    ) {
      final repository = ref.watch(activityLogRepositoryProvider);
      return repository.getActivityLogsPaginated(params.offset, params.limit);
    });
