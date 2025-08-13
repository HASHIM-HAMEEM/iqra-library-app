import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:library_registration_app/domain/entities/subscription.dart';

class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({
    required this.subscription,
    this.onTap,
    this.onEdit,
    this.onCancel,
    this.onRenew,
    this.onDelete,
    this.studentName,
    super.key,
  });

  final Subscription subscription;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onRenew;
  final VoidCallback? onDelete;
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
            child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with plan name and status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subscription.planName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _buildStatusChip(theme),
                    const SizedBox(width: 4),
                    _buildOverflowMenu(context, theme),
                  ],
                ),
                const SizedBox(height: 6),

                // Student ID
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        studentName ?? subscription.studentId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Date range and Amount in a row
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dateFormatter.format(subscription.startDate)} - ${dateFormatter.format(subscription.endDate)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        currencyFormatter.format(subscription.amount),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Days remaining (for active subscriptions)
                if (subscription.status == SubscriptionStatus.active)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _buildDaysRemaining(theme),
                  ),

                const SizedBox(height: 8),

                // No inline destructive buttons; use 3-dot menu
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (subscription.status) {
      case SubscriptionStatus.active:
        backgroundColor = const Color(0xFF10B981).withValues(alpha: 0.1);
        textColor = const Color(0xFF10B981);
        icon = Icons.check_circle_outline;
      case SubscriptionStatus.expired:
        backgroundColor = theme.colorScheme.error.withValues(alpha: 0.1);
        textColor = theme.colorScheme.error;
        icon = Icons.schedule_outlined;
      case SubscriptionStatus.cancelled:
        backgroundColor = theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.1,
        );
        textColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.cancel_outlined;
      case SubscriptionStatus.pending:
        backgroundColor = const Color(0xFFF59E0B).withValues(alpha: 0.1);
        textColor = const Color(0xFFF59E0B);
        icon = Icons.pending_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            subscription.status.name.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysRemaining(ThemeData theme) {
    final now = DateTime.now();
    final daysRemaining = subscription.endDate.difference(now).inDays;

    Color color;
    IconData icon;

    if (daysRemaining <= 7) {
      color = theme.colorScheme.error;
      icon = Icons.warning_outlined;
    } else if (daysRemaining <= 30) {
      color = const Color(0xFFF59E0B);
      icon = Icons.schedule_outlined;
    } else {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle_outline;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          daysRemaining > 0
              ? '$daysRemaining days remaining'
              : 'Expired ${daysRemaining.abs()} days ago',
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Removed old inline buttons in favor of overflow menu

  Widget _buildOverflowMenu(BuildContext context, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            if (onEdit != null) onEdit!();
            break;
          case 'renew':
            if (onRenew != null) onRenew!();
            break;
          case 'cancel':
            if (onCancel != null) onCancel!();
            break;
          case 'delete':
            if (onDelete != null) onDelete!();
            break;
        }
      },
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<String>>[];
        items.add(
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: const [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
        );
        if (onRenew != null && subscription.status == SubscriptionStatus.expired) {
          items.add(
            PopupMenuItem<String>(
              value: 'renew',
              child: Row(
                children: const [
                  Icon(Icons.refresh_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Renew'),
                ],
              ),
            ),
          );
        }
        if (onCancel != null && subscription.status == SubscriptionStatus.active) {
          items.add(
            PopupMenuItem<String>(
              value: 'cancel',
              child: Row(
                children: const [
                  Icon(Icons.cancel_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Cancel'),
                ],
              ),
            ),
          );
        }
        if (onDelete != null) {
          items.add(const PopupMenuDivider());
          items.add(
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
          );
        }
        return items;
      },
    );
  }
}
