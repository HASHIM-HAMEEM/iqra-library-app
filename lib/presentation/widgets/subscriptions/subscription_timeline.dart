import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';

class SubscriptionTimeline extends StatelessWidget {
  const SubscriptionTimeline({
    required this.subscriptions,
    this.onRefresh,
    this.studentNamesById,
    super.key,
  });

  final List<Subscription> subscriptions;
  final VoidCallback? onRefresh;
  final Map<String, String>? studentNamesById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group subscriptions by month for timeline view
    final groupedSubscriptions = _groupSubscriptionsByMonth(subscriptions);

    if (groupedSubscriptions.isEmpty) {
      return const Center(child: Text('No subscriptions to display'));
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedSubscriptions.length,
      itemBuilder: (context, index) {
        final entry = groupedSubscriptions.entries.elementAt(index);
        final monthYear = entry.key;
        final monthSubscriptions = entry.value;

        return _buildTimelineMonth(
          context,
          theme,
          monthYear,
          monthSubscriptions,
          index == 0,
          index == groupedSubscriptions.length - 1,
        );
      },
    );
  }

  Map<String, List<Subscription>> _groupSubscriptionsByMonth(
    List<Subscription> subscriptions,
  ) {
    final grouped = <String, List<Subscription>>{};
    final formatter = DateFormat('MMMM yyyy');

    for (final subscription in subscriptions) {
      final monthKey = formatter.format(subscription.startDate);
      grouped.putIfAbsent(monthKey, () => []).add(subscription);
    }

    // Sort by date (most recent first)
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a.key);
        final dateB = DateFormat('MMMM yyyy').parse(b.key);
        return dateB.compareTo(dateA);
      });

    return Map.fromEntries(sortedEntries);
  }

  Widget _buildTimelineMonth(
    BuildContext context,
    ThemeData theme,
    String monthYear,
    List<Subscription> subscriptions,
    bool isFirst,
    bool isLast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line
        SizedBox(
          width: 60,
          child: Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: theme.colorScheme.outline,
                ),

              // Month indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),

              if (!isLast)
                Container(
                  width: 2,
                  height: 100, // Fixed height instead of Expanded
                  color: theme.colorScheme.outline,
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month header
                Text(
                  monthYear,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  '${subscriptions.length} subscription${subscriptions.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Subscriptions for this month
                ...subscriptions.map(
                  (subscription) =>
                      _buildTimelineSubscriptionCard(theme, subscription),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSubscriptionCard(
    ThemeData theme,
    Subscription subscription,
  ) {
    final dateFormatter = DateFormat('MMM dd');
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with plan name and status
          Row(
            children: [
              Flexible(
                child: Text(
                  subscription.planName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildStatusIndicator(theme, subscription.status),
            ],
          ),
          const SizedBox(height: 8),

          // Details row
          Row(
            children: [
              // Student ID
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        studentNamesById?[subscription.studentId] ??
                            subscription.studentId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Date range
              Flexible(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${dateFormatter.format(subscription.startDate)} - ${dateFormatter.format(subscription.endDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Amount (formatted with symbol; no extra icon to avoid duplicates)
              Text(
                currencyFormatter.format(subscription.amount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ],
          ),

          // Progress bar for active subscriptions
          if (subscription.status == SubscriptionStatus.active) ...[
            const SizedBox(height: 12),
            _buildProgressBar(theme, subscription),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, SubscriptionStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case SubscriptionStatus.active:
        color = const Color(0xFF10B981);
        icon = Icons.check_circle;
      case SubscriptionStatus.expired:
        color = theme.colorScheme.error;
        icon = Icons.cancel;
      case SubscriptionStatus.cancelled:
        color = theme.colorScheme.onSurfaceVariant;
        icon = Icons.block;
      case SubscriptionStatus.pending:
        color = const Color(0xFFF59E0B);
        icon = Icons.pending;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildProgressBar(ThemeData theme, Subscription subscription) {
    final now = DateTime.now();
    // Normalize to day precision and use inclusive range so same-day subscriptions work
    final startDay = DateTime(
      subscription.startDate.year,
      subscription.startDate.month,
      subscription.startDate.day,
    );
    final endDay = DateTime(
      subscription.endDate.year,
      subscription.endDate.month,
      subscription.endDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    final totalDaysRaw = endDay.difference(startDay).inDays + 1; // inclusive
    final totalDays = totalDaysRaw <= 0 ? 1 : totalDaysRaw;
    final elapsedRaw = today.difference(startDay).inDays + 1; // inclusive
    final elapsedDays = elapsedRaw.clamp(0, totalDays);
    final progress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final remainingDays = endDay.difference(today).inDays + 1; // inclusive

    Color progressColor;
    if (remainingDays <= 7) {
      progressColor = theme.colorScheme.error;
    } else if (remainingDays <= 30) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = const Color(0xFF10B981);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              remainingDays > 0 ? '$remainingDays days left' : 'Expired',
              style: theme.textTheme.labelSmall?.copyWith(
                color: progressColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        ),
      ],
    );
  }
}
