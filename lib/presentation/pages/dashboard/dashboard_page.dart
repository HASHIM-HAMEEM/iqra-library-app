import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/app_colors.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';
// import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/providers/export/export_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/compact_stat_tile.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:library_registration_app/presentation/widgets/common/filter_chips.dart';
import 'package:library_registration_app/presentation/widgets/common/page_header.dart';
import 'package:library_registration_app/presentation/widgets/common/quick_action_card.dart';
import 'package:library_registration_app/presentation/widgets/common/recent_activity_card.dart';
import 'package:library_registration_app/presentation/widgets/common/section_header.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _selectedRange = 'Today';

  void _showNotification(
    String message, {
    NotificationType type = NotificationType.success,
  }) {
    CustomNotification.show(context, message: message, type: type);
  }

  ({DateTime startDate, DateTime endDate}) _getRangeDates() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (_selectedRange) {
      case 'Today':
        return (
          startDate: todayStart,
          endDate: todayStart
              .add(const Duration(days: 1))
              .subtract(const Duration(microseconds: 1)),
        );
      case 'Week':
        final start = todayStart.subtract(const Duration(days: 6));
        return (
          startDate: start,
          endDate: todayStart
              .add(const Duration(days: 1))
              .subtract(const Duration(microseconds: 1)),
        );
      case 'Month':
        final start = DateTime(now.year, now.month);
        final nextMonth = DateTime(now.year, now.month + 1);
        return (
          startDate: start,
          endDate: nextMonth.subtract(const Duration(microseconds: 1)),
        );
      default:
        return (
          startDate: todayStart,
          endDate: todayStart
              .add(const Duration(days: 1))
              .subtract(const Duration(microseconds: 1)),
        );
    }
  }

  Future<void> _onRefresh() async {
    // Refresh all providers
    ref
      ..invalidate(studentsCountProvider)
      ..invalidate(activeSubscriptionsCountProvider)
      ..invalidate(totalRevenueProvider)
      ..invalidate(studentsProvider)
      ..invalidate(subscriptionsProvider);

    _showNotification('Dashboard refreshed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Always-live totals for tiles
    final studentsCount = ref.watch(studentsCountProvider);
    final activeSubscriptionsCount = ref.watch(
      activeSubscriptionsCountProvider,
    );
    final range = _getRangeDates();
    // Recompute provider key when range changes by selected chip
    final totalRevenue = ref.watch(
      revenueByDateRangeProvider((
        startDate: range.startDate,
        endDate: range.endDate,
      )),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.getMaxContentWidth(context),
            ),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Modern Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                    ).copyWith(top: 8),
                    child: _buildModernHeader(theme),
                  ),
                ),

                // Time Filter Chips
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: FilterChipsRow(
                      options: const ['Today', 'Week', 'Month'],
                      selected: _selectedRange,
                      onSelected: (v) => setState(() => _selectedRange = v),
                    ),
                  ),
                ),

                // Compact Stats Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                    ).copyWith(top: 12),
                    child: _buildCompactStats(
                      theme,
                      studentsCount,
                      activeSubscriptionsCount,
                      totalRevenue,
                    ),
                  ),
                ),

                // Quick Actions Section
                SliverToBoxAdapter(
                  child: Container(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    child: const SectionHeader(
                      title: 'Quick Actions',
                      subtitle: 'Common tasks and shortcuts',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    child: ClipRRect(
                      borderRadius: AppRadius.borderLg,
                      child: RepaintBoundary(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 150),
                          child: Container(
                            decoration: BoxDecoration(
                              // Glassmorphism effect
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                                  theme.colorScheme.surface.withValues(
                                    alpha: 0.6,
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: AppRadius.borderXl,
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withValues(
                                    alpha: 0.04,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: ResponsiveUtils.isMobile(context)
                                ? SizedBox(
                                    height: 166,
                                    child: _buildQuickActionsGrid(context),
                                  )
                                : _buildQuickActionsGrid(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Recent Activity Section
                SliverToBoxAdapter(
                  child: Container(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    child: SectionHeader(
                      title: 'Recent Activity',
                      subtitle: 'Latest updates and changes',
                      action: TextButton.icon(
                        onPressed: () => GoRouter.of(context).go('/activity'),
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text('View all'),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    margin: const EdgeInsets.only(top: 16, bottom: 32),
                    child: const RecentActivityCard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return PageHeader(
      title: greeting,
      subtitle: dateStr,
      showBack: false,
      actions: [_buildHeaderProfileAvatar(theme)],
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // Greeting section removed per request

  Widget _buildHeaderProfileAvatar(ThemeData theme) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final orientation = MediaQuery.of(context).orientation;

    double diameter;
    if (isDesktop) {
      diameter = 56;
    } else if (isTablet) {
      diameter = orientation == Orientation.portrait ? 56 : 52;
    } else {
      diameter = 52;
    }
    final iconSize = (diameter * 0.56).clamp(22.0, 36.0);

    final cs = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final bgColor = isLight
        ? cs.surface.withValues(alpha: 0.98)
        : cs.surfaceContainerHighest.withValues(alpha: 0.75);
    final fgColor = cs.onSurface;

    return GestureDetector(
      onTap: () {
        showDialog<AlertDialog>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Profile'),
            content: _buildProfileDialogContent(theme),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(authProvider.notifier).logout();
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.65),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: diameter - 6,
          height: diameter - 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.person_rounded, size: iconSize, color: fgColor),
        ),
      ),
    );
  }

  Widget _buildProfileDialogContent(ThemeData theme) {
    final auth = ref.watch(authProvider);
    final email = auth.user?.email ?? auth.lastKnownEmail ?? 'unknown';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Admin: $email',
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactStats(
    ThemeData theme,
    AsyncValue<int> studentsCount,
    AsyncValue<int> activeSubscriptionsCount,
    AsyncValue<double> totalRevenue,
  ) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final currencyFormatter = NumberFormat.simpleCurrency(locale: locale);
    final tiles = [
      CompactStatTile(
        icon: Icons.people_outline_rounded,
        color: theme.colorScheme.primary,
        label: 'Total Students',
        value: studentsCount.when(
          data: (v) => '$v',
          loading: () => '...',
          error: (_, __) => '—',
        ),
      ),
      CompactStatTile(
        icon: Icons.card_membership_outlined,
        color: AppColors.success,
        label: 'Active Subs',
        value: activeSubscriptionsCount.when(
          data: (v) => '$v',
          loading: () => '...',
          error: (_, __) => '—',
        ),
      ),
      CompactStatTile(
        icon: Icons.payments_outlined,
        color: AppColors.warning,
        label: 'Revenue · $_selectedRange',
        value: totalRevenue.when(
          data: currencyFormatter.format,
          loading: () => '...',
          error: (_, __) => '—',
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Column(
            children: [
              Row(children: [Expanded(child: tiles[0])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: tiles[1])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: tiles[2])]),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 12),
            Expanded(child: tiles[1]),
            const SizedBox(width: 12),
            Expanded(child: tiles[2]),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      {
        'title': 'Add Student',
        'subtitle': 'Register new student',
        'icon': CupertinoIcons.person_add,
        'color': AppColors.info,
        'onTap': () {
          GoRouter.of(context).go('/students/add');
          _showNotification('Navigating to Add Student');
        },
      },
      {
        'title': 'New Subscription',
        'subtitle': 'Create subscription plan',
        'icon': CupertinoIcons.creditcard,
        'color': AppColors.success,
        'onTap': () {
          GoRouter.of(context).go('/subscriptions');
          _showNotification('Navigating to Subscriptions');
        },
      },
      {
        'title': 'View Students',
        'subtitle': 'Manage all students',
        'icon': CupertinoIcons.person_2,
        'color': AppColors.purple,
        'onTap': () {
          GoRouter.of(context).go('/students');
          _showNotification('Navigating to Students List');
        },
      },
      {
        'title': 'Export Data',
        'subtitle': 'Download reports',
        'icon': CupertinoIcons.square_arrow_down,
        'color': AppColors.warning,
        'onTap': _showExportOptionsSheet,
      },
    ];

    if (ResponsiveUtils.isMobile(context)) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return SizedBox(
            width: 160,
            child: QuickActionCard(
              title: action['title']! as String,
              subtitle: action['subtitle']! as String,
              icon: action['icon']! as IconData,
              color: action['color']! as Color,
              onTap: action['onTap']! as VoidCallback,
            ),
          );
        },
      );
    } else {
      final width = MediaQuery.of(context).size.width;
      final isTablet = ResponsiveUtils.isTablet(context);
      // Cross axis columns: 2 on small tablets, 3 on large tablets, 4 on desktop
      final crossAxisCount = width < 900
          ? 2
          : width < 1200
          ? 3
          : 4;
      // Slightly wider aspect on tablets for better balance
      final aspect = isTablet ? 1.35 : 1.2;
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspect,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return RepaintBoundary(
            child: QuickActionCard(
              title: action['title']! as String,
              subtitle: action['subtitle']! as String,
              icon: action['icon']! as IconData,
              color: action['color']! as Color,
              onTap: action['onTap']! as VoidCallback,
            ),
          );
        },
      );
    }
  }

  void _showExportOptionsSheet() {
    final theme = Theme.of(context);
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Export Data',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            _buildExportOption(
              icon: Icons.download_outlined,
              title: 'Export All Data',
              subtitle: 'Students, subscriptions, and activity logs',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(ExportType.all);
              },
            ),

            _buildExportOption(
              icon: Icons.people_outline,
              title: 'Export Students Only',
              subtitle: 'Student information and details',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(ExportType.students);
              },
            ),

            _buildExportOption(
              icon: Icons.card_membership_outlined,
              title: 'Export Subscriptions Only',
              subtitle: 'Subscription plans and payments',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(ExportType.subscriptions);
              },
            ),

            _buildExportOption(
              icon: Icons.history_outlined,
              title: 'Export Activity Logs Only',
              subtitle: 'System activity and audit trail',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(ExportType.activityLogs);
              },
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.outline,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  void _showExportSheet(ExportType exportType) {
    final theme = Theme.of(context);
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final exportState = ref.watch(exportNotifierProvider);
            final exportNotifier = ref.read(exportNotifierProvider.notifier);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _getExportTitle(exportType),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (exportState.status == ExportStatus.loading)
                  ..._buildExportProgress(exportState, theme)
                else if (exportState.status == ExportStatus.success)
                  ..._buildExportSuccess(exportState, exportNotifier, theme)
                else if (exportState.status == ExportStatus.error)
                  ..._buildExportError(exportState, exportNotifier, theme)
                else
                  ..._buildExportIdle(exportType, exportNotifier, theme),

                const SizedBox(height: 16),

                if (exportState.status != ExportStatus.loading)
                  TextButton(
                    onPressed: () {
                      exportNotifier.resetState();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Close'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _getExportTitle(ExportType type) {
    switch (type) {
      case ExportType.all:
        return 'Export All Data';
      case ExportType.students:
        return 'Export Students Data';
      case ExportType.subscriptions:
        return 'Export Subscriptions Data';
      case ExportType.activityLogs:
        return 'Export Activity Logs';
    }
  }

  List<Widget> _buildExportProgress(ExportState state, ThemeData theme) {
    return [
      CircularProgressIndicator(
        value: state.progress,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      const SizedBox(height: 16),
      Text(
        'Exporting data... ${(state.progress * 100).toInt()}%',
        style: theme.textTheme.bodyMedium,
      ),
    ];
  }

  List<Widget> _buildExportSuccess(
    ExportState state,
    ExportNotifier notifier,
    ThemeData theme,
  ) {
    return [
      Icon(
        Icons.check_circle_outline,
        color: theme.colorScheme.primary,
        size: 48,
      ),
      const SizedBox(height: 16),
      Text(
        'Export completed successfully!',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Text(
        'File saved to: ${state.filePath?.split('/').last}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: () => notifier.shareExportedFile(),
        icon: const Icon(Icons.share),
        label: const Text('Share File'),
      ),
    ];
  }

  List<Widget> _buildExportError(
    ExportState state,
    ExportNotifier notifier,
    ThemeData theme,
  ) {
    return [
      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
      const SizedBox(height: 16),
      Text(
        'Export failed',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.error,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        state.errorMessage ?? 'Unknown error occurred',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: () => notifier.resetState(),
        child: const Text('Try Again'),
      ),
    ];
  }

  List<Widget> _buildExportIdle(
    ExportType type,
    ExportNotifier notifier,
    ThemeData theme,
  ) {
    return [
      Icon(Icons.download_outlined, color: theme.colorScheme.primary, size: 48),
      const SizedBox(height: 16),
      Text(
        'Ready to export ${_getExportDescription(type)}',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        'This will generate an Excel file with the selected data.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: () => notifier.exportData(type),
        icon: const Icon(Icons.download),
        label: const Text('Start Export'),
      ),
    ];
  }

  String _getExportDescription(ExportType type) {
    switch (type) {
      case ExportType.all:
        return 'all library data';
      case ExportType.students:
        return 'student information';
      case ExportType.subscriptions:
        return 'subscription data';
      case ExportType.activityLogs:
        return 'activity logs';
    }
  }
}
