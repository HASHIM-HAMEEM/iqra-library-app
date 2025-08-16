// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';

class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({
    required this.subscription,
    this.onTap,
    this.onEdit,
    this.onCancel,
    this.onRenew,
    this.onDelete,
    this.studentName,
    this.studentAvatarPath,
    this.studentInitials,
    super.key,
  });

  final Subscription subscription;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onRenew;
  final VoidCallback? onDelete;
  final String? studentName;
  final String? studentAvatarPath;
  final String? studentInitials;

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
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth > 520;
                final avatar = _buildAvatar(theme, size: wide ? 40 : 36);
                final planStyle = theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: avatar + plan + status + menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        avatar,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            subscription.planName,
                            style: planStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(theme),
                        const SizedBox(width: 4),
                        _buildOverflowMenu(context, theme),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Student name
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
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
                    // Date range • Amount (wrap to avoid overflow on small heights)
                    Wrap(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              '${dateFormatter.format(subscription.startDate)} – ${dateFormatter.format(subscription.endDate)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            currencyFormatter.format(subscription.amount),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subscription.status == SubscriptionStatus.active)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildDaysRemaining(theme),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, {double size = 36}) {
    return AsyncAvatar(
      imagePath: studentAvatarPath,
      initials: (studentInitials != null && studentInitials!.isNotEmpty)
          ? studentInitials!
          : (studentName?.isNotEmpty == true
              ? studentName!.trim().split(RegExp(r"\s+")).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
              : '?'),
      size: size,
      fallbackIcon: Icons.person_outline,
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
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(
      subscription.endDate.year,
      subscription.endDate.month,
      subscription.endDate.day,
    );
    final daysRemaining = endDay.difference(today).inDays + 1; // inclusive

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
              : (daysRemaining == 0 ? 'Expires today' : 'Expired ${daysRemaining.abs()} days ago'),
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
