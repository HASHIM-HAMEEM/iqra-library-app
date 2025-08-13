import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/presentation/providers/activity_logs/activity_logs_provider.dart';

class RecentActivityCard extends ConsumerWidget {
  const RecentActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentActivities = ref.watch(recentActivityLogsProvider(10));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            recentActivities.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return _buildEmptyState(theme);
                }
                return Column(
                  children: activities.take(5).map((activity) {
                    return _buildActivityItem(theme, activity);
                  }).toList(),
                );
              },
              loading: () => _buildLoadingState(theme),
              error: (error, stack) => _buildErrorState(theme, error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(ThemeData theme, ActivityLog activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getActivityColor(
                    activity.activityType,
                  ).withValues(alpha: 0.15),
                  _getActivityColor(
                    activity.activityType,
                  ).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getActivityColor(
                  activity.activityType,
                ).withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              _getActivityIcon(activity.activityType),
              color: _getActivityColor(activity.activityType),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  activity.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(activity.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.history_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activity will appear here as you use the app',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(ThemeData theme, Object error) {
    // Print error to console for debugging
    debugPrint('RecentActivityCard error: $error');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load activity',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.studentCreated:
      case ActivityType.studentUpdated:
        return Icons.person_outline;
      case ActivityType.studentDeleted:
        return Icons.person_off_outlined;
      case ActivityType.studentRestored:
        return Icons.restore_outlined;
      case ActivityType.subscriptionCreated:
      case ActivityType.subscriptionUpdated:
        return Icons.card_membership_outlined;
      case ActivityType.subscriptionCancelled:
        return Icons.cancel_outlined;
      case ActivityType.subscriptionRenewed:
        return Icons.refresh_outlined;
      case ActivityType.dataBackup:
        return Icons.backup_outlined;
      case ActivityType.dataRestore:
        return Icons.restore_outlined;
      case ActivityType.login:
        return Icons.login_outlined;
      case ActivityType.logout:
        return Icons.logout_outlined;
      case ActivityType.settingsChanged:
        return Icons.settings_outlined;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.studentCreated:
      case ActivityType.studentRestored:
      case ActivityType.subscriptionCreated:
      case ActivityType.subscriptionRenewed:
      case ActivityType.dataBackup:
      case ActivityType.dataRestore:
        return const Color(0xFF10B981); // Success green
      case ActivityType.login:
        return const Color(0xFF3B82F6); // Blue
      case ActivityType.studentUpdated:
      case ActivityType.subscriptionUpdated:
      case ActivityType.settingsChanged:
        return const Color(0xFFF59E0B); // Warning yellow
      case ActivityType.studentDeleted:
      case ActivityType.subscriptionCancelled:
      case ActivityType.logout:
        return const Color(0xFFEF4444); // Error red
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
