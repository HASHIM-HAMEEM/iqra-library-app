import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/activity_logs/activity_logs_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';

class StudentDetailsPage extends ConsumerWidget {

  const StudentDetailsPage({required this.studentId, super.key});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(studentByIdProvider(studentId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Student Details'),
        actions: [
          studentAsync.when(
            data: (student) => IconButton(
              tooltip: 'Edit',
              onPressed: student == null
                  ? null
                  : () => context.go('/students/edit/${student.id}'),
              icon: const Icon(Icons.edit_outlined),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) return _buildNotFound(context, ref);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentByIdProvider(studentId));
              ref.invalidate(activeSubscriptionByStudentProvider(studentId));
              ref.invalidate(
                activityLogsByEntityProvider((
                  entityId: studentId,
                  entityType: 'Student',
                )),
              );
              await ref.read(studentByIdProvider(studentId).future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _maxWidthFor(context)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, student),
                        const SizedBox(height: 16),
                        _buildIdentitySection(context, student),
                        const SizedBox(height: 12),
                        _buildContactSection(context, student),
                        const SizedBox(height: 12),
                        _buildLibrarySection(context, ref, student),
                        const SizedBox(height: 12),
                        _buildMetaSection(context, student),
                        const SizedBox(height: 12),
                        _buildLastActivitySection(context, ref, student),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => _buildLoadingSkeleton(context),
        error: (e, _) => _buildErrorState(context, ref, e),
      ),
    );
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
        _buildAvatar(theme, student),
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

  Widget _buildAvatar(ThemeData theme, Student student) {
    final path = student.profileImagePath;
    final file = (path != null) ? File(path) : null;
    final hasFile = file != null && file.existsSync();
    return CircleAvatar(
      radius: 36,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: hasFile
          ? ClipOval(
              child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
            )
          : Text(
              student.initials,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
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
    final phone = s.phone?.isNotEmpty == true ? s.phone! : '—';
    final address = s.address?.isNotEmpty == true ? s.address! : '—';
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
      activityLogsByEntityProvider((entityId: s.id, entityType: 'Student')),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
    final text =
        valueWidget ??
        SelectableText(
          value ?? '—',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            height: multiline ? 1.3 : 1.2,
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
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
}
