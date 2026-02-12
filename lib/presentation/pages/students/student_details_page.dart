import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/core/utils/error_mapper.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';
import 'package:library_registration_app/core/utils/telemetry_service.dart';
import 'package:library_registration_app/presentation/providers/activity_logs/activity_logs_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_notifier.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
// cached_network_image removed; using Image.network with errorBuilder
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';
import 'package:library_registration_app/presentation/pages/students/profile_photo_view_page.dart';
import 'package:library_registration_app/presentation/widgets/common/page_header.dart';

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
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                    ).copyWith(top: 8),
                    child: _buildModernHeader(context, student),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _maxWidthFor(context),
                      ),
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
    return PageHeader(
      title: 'Student Profile',
      subtitle: 'View and manage details',
      onBack: () => context.pop(),
      actions: [
        IconButton(
          onPressed: () => context.go('/students/id-card/${student.id}'),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
          icon: const Icon(Icons.badge_outlined),
          tooltip: 'ID Card',
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => context.go('/students/${student.id}/edit'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
        ),
      ],
    );
  }
}

Widget _buildResponsiveSections(
  BuildContext context,
  WidgetRef ref,
  Student student,
) {
  // New Hero-like Profile Header
  final profileHeader = _buildProfileHero(context, student);

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
      final bool isDesktop = maxW >= 900;

      if (!isDesktop) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            profileHeader,
            const SizedBox(height: 24),
            for (final s in sections) ...[s, const SizedBox(height: 16)],
            const SizedBox(height: 32),
          ],
        );
      }

      // Desktop Layout
      return Column(
        children: [
          profileHeader,
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    sections[0], // Identity
                    const SizedBox(height: 16),
                    sections[1], // Contact
                    const SizedBox(height: 16),
                    sections[3], // Meta
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    sections[2], // Library
                    const SizedBox(height: 16),
                    sections[4], // Activity
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

Widget _buildProfileHero(BuildContext context, Student student) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.primary.withValues(alpha: 0.1),
          theme.colorScheme.surface,
        ],
      ),
      borderRadius: AppRadius.borderPill,
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    ),
    child: Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 300),
                opaque: false,
                pageBuilder: (ctx, anim, _) => FadeTransition(
                  opacity: anim,
                  child: ProfilePhotoViewPage(
                    imagePath: student.profileImagePath,
                    fallbackInitials: student.initials,
                    heroTag: 'hero_${student.id}',
                    title: student.fullName,
                  ),
                ),
              ),
            );
          },
          child: Hero(
            tag: 'hero_${student.id}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AsyncAvatar(
                imagePath: student.profileImagePath,
                initials: student.initials,
                size: 100,
                fallbackIcon: Icons.person_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          student.fullName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: AppRadius.borderXl,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.email_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                student.email,
                style: theme.textTheme.bodyMedium?.copyWith(
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

// _buildHeader removed as it is replaced by _buildProfileHero

// _buildAvatar removed as it is replaced by _buildProfileHero usage

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
          prefixIcon: Icon(Icons.payments_outlined),
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
                'The new end date overlaps a previous period. Proceed only if you are backdating intentionally.',
              ),
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

// Updated Cards
Widget _sectionCard(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  IconData? leadingIcon,
}) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.borderXl,
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      boxShadow: [
        BoxShadow(
          color: theme.shadowColor.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leadingIcon != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Icon(
                  leadingIcon,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (leadingIcon != null) const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

// Helper for _infoRow to look better
Widget _infoRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  String? value,
  Widget? valueWidget,
  bool multiline = false,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        // Icon aligned with text
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              if (valueWidget != null)
                valueWidget
              else
                Text(
                  value ?? '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
      ],
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
                        borderRadius: AppRadius.borderLg,
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
                  onPressed: () =>
                      _renewSubscriptionForStudent(context, ref, sub),
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
      _infoRow(
        context,
        icon: Icons.verified_user_outlined,
        label: 'ID Card Token',
        value: (s.idCardToken ?? '').isNotEmpty ? 'Issued' : 'Pending',
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
// Loading Skeleton
Widget _buildLoadingSkeleton(BuildContext context) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.all(24),
    child: SingleChildScrollView(
      child: Column(
        children: [
          // Profile Hero Skeleton
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: AppRadius.borderPill,
            ),
          ),
          const SizedBox(height: 32),
          // Cards
          for (int i = 0; i < 3; i++) ...[
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: AppRadius.borderXl,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
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

Widget _buildErrorState(
  BuildContext context,
  WidgetRef ref,
  Object error,
  String studentId,
) {
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
