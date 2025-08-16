import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/core/utils/error_mapper.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/core/utils/telemetry_service.dart';
import 'package:library_registration_app/presentation/providers/activity_logs/activity_logs_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_notifier.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
// cached_network_image removed; using Image.network with errorBuilder
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';

class StudentDetailsPage extends ConsumerWidget {

  const StudentDetailsPage({required this.studentId, super.key});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(studentByIdProvider(studentId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: studentAsync.when(
        data: (student) {
          if (student == null) return _buildNotFound(context, ref);
          return RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(studentByIdProvider(studentId))
                ..invalidate(activeSubscriptionByStudentProvider(studentId))
                ..invalidate(
                  activityLogsByEntityProvider((
                    entityId: studentId,
                    entityType: 'student',
                  )),
                );
              await ref.read(studentByIdProvider(studentId).future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Modern Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(context).copyWith(top: 8),
                    child: _buildModernHeader(context, student),
                  ),
                ),
                
                // Content
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidthFor(context)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildResponsiveSections(context, ref, student),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => _buildLoadingSkeleton(context),
        error: (e, _) => _buildErrorState(context, ref, e, studentId),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, Student student) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                student.fullName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: () => context.go('/students/edit/${student.id}'),
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit',
        ),
      ],
    );
  }
}

  Widget _buildResponsiveSections(BuildContext context, WidgetRef ref, Student student) {
    final header = _buildHeader(context, student);
    final sections = <Widget>[
      _buildIdentitySection(context, student),
      _buildContactSection(context, student),
      _buildLibrarySection(context, ref, student),
      _buildMetaSection(context, student),
      _buildLastActivitySection(context, ref, student),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        // Two columns for widths >= 900
        final bool twoCols = maxW >= 900;
        if (!twoCols) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 16),
              for (int i = 0; i < sections.length; i++) ...[
                sections[i],
                if (i != sections.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 24),
            ],
          );
        }
        final double gap = 16;
        final double cardW = (maxW - gap) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 16),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final s in sections)
                  SizedBox(
                    width: cardW,
                    child: s,
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Future<void> _renewSubscriptionForStudent(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: sub.endDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;

    final amountCtrl = TextEditingController(text: sub.amount.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renew Subscription'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Renewal amount',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amountCtrl.text.trim());
              if (v == null || v < 0) {
                CustomNotification.show(
                  ctx,
                  message: 'Enter a valid amount',
                  type: NotificationType.error,
                );
                return;
              }
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (amount == null) return;

    try {
      await ref
          .read(subscriptionsNotifierProvider.notifier)
          .renewSubscription(
            sub.id,
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999),
            amount,
          );
      if (context.mounted) {
        CustomNotification.show(
          context,
          message: 'Subscription renewed successfully',
          type: NotificationType.success,
        );
        // refresh widgets that display subscription
        ref.invalidate(activeSubscriptionByStudentProvider(sub.studentId));
      }
    } catch (e, st) {
      TelemetryService.instance.captureException(
        e,
        st,
        feature: 'renew_subscription_student_details',
        context: {
          'subscription_id': sub.id,
          'student_id': sub.studentId,
          'picked': picked.toIso8601String(),
        },
      );
      if (!context.mounted) return;
      final msg = ErrorMapper.friendly(e);
      final proceedOverlap = ErrorMapper.isOverlap(e)
          ? await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirm renewal change'),
                content: const Text(
                    'The new end date overlaps a previous period. Proceed only if you are backdating intentionally.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Adjust dates'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Proceed anyway'),
                  ),
                ],
              ),
            )
          : false;
      if (proceedOverlap == true) {
        await ref
            .read(subscriptionsNotifierProvider.notifier)
            .renewSubscription(sub.id, picked, amount, allowOverlap: true);
        if (!context.mounted) return;
        CustomNotification.show(
          context,
          message: 'Subscription renewed successfully',
          type: NotificationType.success,
        );
        ref.invalidate(activeSubscriptionByStudentProvider(sub.studentId));
        return;
      }

      CustomNotification.show(
        context,
        message: msg,
        type: NotificationType.error,
      );
    }
  }

  double _maxWidthFor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 1000;
    if (width >= 800) return 720;
    return double.infinity;
  }

  Widget _buildHeader(BuildContext context, Student student) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _buildAvatar(context, theme, student),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.fullName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                student.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, ThemeData theme, Student student) {
    return GestureDetector(
      onTap: () => _showProfilePreview(context, student),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AsyncAvatar(
          imagePath: student.profileImagePath,
          initials: student.initials,
          size: 72,
          fallbackIcon: Icons.person_outline,
        ),
      ),
    );
  }

  Widget _fallbackInitials(ThemeData theme, Student student) {
    return Text(
      student.initials,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildIdentitySection(BuildContext context, Student s) {
    final df = DateFormat.yMMMMd();
    return _sectionCard(
      context,
      title: 'Identity',
      children: [
        _infoRow(
          context,
          icon: Icons.badge_outlined,
          label: 'Student ID',
          value: s.id,
        ),
        _infoRow(
          context,
          icon: Icons.event_outlined,
          label: 'Date of Birth',
          value: df.format(s.dateOfBirth),
        ),
        _infoRow(
          context,
          icon: Icons.cake_outlined,
          label: 'Age',
          value: '${s.age} years',
        ),
        if (s.seatNumber != null && s.seatNumber!.isNotEmpty)
          _infoRow(
            context,
            icon: Icons.event_seat_outlined,
            label: 'Seat Number',
            value: s.seatNumber,
          ),
        _infoRow(
          context,
          icon: Icons.person_outline,
          label: 'Full Name',
          value: s.fullName,
        ),
      ],
      leadingIcon: Icons.perm_identity,
    );
  }

  Widget _buildContactSection(BuildContext context, Student s) {
    final phone = (s.phone?.isNotEmpty ?? false) ? s.phone! : '—';
    final address = (s.address?.isNotEmpty ?? false) ? s.address! : '—';
    return _sectionCard(
      context,
      title: 'Contact',
      children: [
        _infoRow(
          context,
          icon: Icons.email_outlined,
          label: 'Email',
          value: s.email,
        ),
        _infoRow(
          context,
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: phone,
        ),
        _infoRow(
          context,
          icon: Icons.home_outlined,
          label: 'Address',
          value: address,
          multiline: true,
        ),
      ],
      leadingIcon: Icons.contact_page_outlined,
    );
  }

  Widget _buildLibrarySection(BuildContext context, WidgetRef ref, Student s) {
    final theme = Theme.of(context);
    final subAsync = ref.watch(activeSubscriptionByStudentProvider(s.id));
    return _sectionCard(
      context,
      title: 'Library',
      children: [
        subAsync.when(
          data: (sub) {
            if (sub == null) {
              return _infoRow(
                context,
                icon: Icons.card_membership_outlined,
                label: 'Subscription',
                value: 'No active subscription',
              );
            }
            final df = DateFormat.yMMMd();
            final statusColor = _statusColor(theme, sub.status);
            return Column(
              children: [
                _infoRow(
                  context,
                  icon: Icons.card_membership_outlined,
                  label: 'Plan',
                  value: sub.planName,
                ),
                const SizedBox(height: 8),
                _infoRow(
                  context,
                  icon: Icons.timelapse_outlined,
                  label: 'Status',
                  valueWidget: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          sub.status.displayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ends ${df.format(sub.endDate)} • ${sub.daysRemaining} days left',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _renewSubscriptionForStudent(context, ref, sub),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Renew Subscription'),
                  ),
                ),
              ],
            );
          },
          loading: () => _inlineLoading(context),
          error: (e, _) => _inlineError(context, 'Failed to load subscription'),
        ),
      ],
      leadingIcon: Icons.local_library_outlined,
    );
  }

  Widget _buildMetaSection(BuildContext context, Student s) {
    final df = DateFormat.yMMMd().add_jm();
    final deleted = s.isDeleted ? 'Yes' : 'No';
    return _sectionCard(
      context,
      title: 'Meta',
      children: [
        _infoRow(
          context,
          icon: Icons.calendar_today_outlined,
          label: 'Created',
          value: df.format(s.createdAt),
        ),
        _infoRow(
          context,
          icon: Icons.update_outlined,
          label: 'Updated',
          value: df.format(s.updatedAt),
        ),
        _infoRow(
          context,
          icon: Icons.delete_outline,
          label: 'Deleted',
          value: deleted,
        ),
      ],
      leadingIcon: Icons.info_outline,
    );
  }

  Widget _buildLastActivitySection(
    BuildContext context,
    WidgetRef ref,
    Student s,
  ) {
    final logsAsync = ref.watch(
      activityLogsByEntityProvider((entityId: s.id, entityType: 'student')),
    );
    return _sectionCard(
      context,
      title: 'Last activity',
      children: [
        logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return _infoRow(
                context,
                icon: Icons.history_toggle_off,
                label: 'Recent',
                value: 'No activity',
              );
            }
            logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            final latest = logs.first;
            final df = DateFormat.yMMMd().add_jm();
            return _infoRow(
              context,
              icon: Icons.history,
              label: latest.activityType.displayName,
              value: df.format(latest.timestamp),
            );
          },
          loading: () => _inlineLoading(context),
          error: (e, _) => _inlineError(context, 'Failed to load activity'),
        ),
      ],
      leadingIcon: Icons.timeline_outlined,
    );
  }

  // Cards and helpers
  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    IconData? leadingIcon,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container
    (
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leadingIcon != null)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(leadingIcon, size: 16, color: cs.primary),
                ),
              if (leadingIcon != null) const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: cs.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
    bool multiline = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = valueWidget ?? SelectableText(
      value ?? '—',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        height: multiline ? 1.35 : 1.25,
        fontWeight: FontWeight.w500,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.secondaryContainer.withValues(alpha: 0.35),
            ),
            child: Icon(icon, size: 14, color: cs.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                text,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ThemeData theme, SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return theme.colorScheme.primary;
      case SubscriptionStatus.expired:
        return theme.colorScheme.error;
      case SubscriptionStatus.cancelled:
        return theme.colorScheme.tertiary;
      case SubscriptionStatus.pending:
        return theme.colorScheme.secondary;
    }
  }

  // Loading / Error / Not Found
  Widget _buildLoadingSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    Widget box({double h = 16, double w = double.infinity}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    box(h: 20, w: 160),
                    const SizedBox(height: 8),
                    box(h: 14, w: 220),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          box(h: 180),
          const SizedBox(height: 12),
          box(h: 140),
        ],
      ),
    );
  }

  Widget _inlineLoading(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _inlineError(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error, String studentId) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load student',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                ref.invalidate(studentByIdProvider(studentId));
                await ref.read(studentByIdProvider(studentId).future);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Student not found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The selected student does not exist or may have been deleted.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePreview(BuildContext context, Student student) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildProfilePreviewContent(ctx, theme, student),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilePreviewContent(BuildContext context, ThemeData theme, Student s) {
  final cs = theme.colorScheme;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Header
      Row(
        children: [
          Icon(Icons.person_outline, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'Profile Preview',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      const SizedBox(height: 12),
      // Card-like profile content
      Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AsyncAvatar(
              imagePath: s.profileImagePath,
              initials: s.initials,
              size: 120,
              fallbackIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            Text(
              s.fullName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                if ((s.phone ?? '').isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(s.phone ?? '-', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                if ((s.address ?? '').isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        s.address ?? '-',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                if ((s.seatNumber ?? '').isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_seat_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Seat ${s.seatNumber}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    );
  }

