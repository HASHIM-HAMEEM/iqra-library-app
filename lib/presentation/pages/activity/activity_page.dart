import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/app_colors.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/presentation/providers/activity_logs/activity_logs_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/page_header.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  // Pagination
  final ScrollController _scrollController = ScrollController();
  final List<ActivityLog> _paged = [];
  bool _isLoadingPage = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextPage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingPage) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() => _isLoadingPage = true);
    try {
      final next = await ref.read(
        activityLogsPaginatedProvider((
          offset: _offset,
          limit: _pageSize,
        )).future,
      );
      if (!mounted) return;
      setState(() {
        _paged.addAll(next);
        _offset += next.length;
        _hasMore = next.length == _pageSize;
        _isLoadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsStream = ref.watch(activityLogsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxContentWidth(context),
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: 'Recent Activity',
                  subtitle: 'Track system actions and updates',
                  onBack: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      GoRouter.of(context).go('/dashboard');
                    }
                  },
                ),
              ),

              // header removed; AppBar provides title

              // Controls
              SliverToBoxAdapter(
                child: Padding(
                  padding: ResponsiveUtils.getResponsivePadding(
                    context,
                  ).copyWith(top: 4),
                  child: const SizedBox.shrink(),
                ),
              ),

              // List
              SliverPadding(
                padding: ResponsiveUtils.getResponsivePadding(
                  context,
                ).copyWith(top: 12, bottom: 24),
                sliver: SliverToBoxAdapter(
                  child: logsStream.when(
                    data: (logs) {
                      final source = _paged.isEmpty ? logs : _paged;
                      final filtered = source.toList();

                      if (filtered.isEmpty) {
                        return _buildEmptyState(theme);
                      }

                      // Desktop: data table view
                      if (ResponsiveUtils.isDesktop(context)) {
                        return _buildActivityDataTable(theme, filtered);
                      }

                      // Mobile/tablet: grouped card list
                      final grouped = <String, List<ActivityLog>>{};
                      for (final a in filtered) {
                        final k = DateFormat('yyyy-MM-dd').format(a.timestamp);
                        (grouped[k] ??= []).add(a);
                      }
                      final days = grouped.keys.toList()
                        ..sort((b, a) => a.compareTo(b));

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: days.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final dayKey = days[index];
                          final list = grouped[dayKey]!;
                          final dayLabel = _friendlyDayLabel(
                            DateTime.parse(dayKey),
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 6,
                                  left: 4,
                                ),
                                child: Text(
                                  dayLabel,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ...list.map(
                                (a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildActivityTile(theme, a),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => _buildLoading(theme),
                    error: (e, _) => _buildError(theme, e),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: _isLoadingPage
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : (!_hasMore
                              ? Text(
                                  'All activity loaded',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                )
                              : const SizedBox.shrink()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityDataTable(ThemeData theme, List<ActivityLog> logs) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  flex: 4,
                  child: Text('Description', style: _thStyle(theme)),
                ),
                Expanded(flex: 2, child: Text('Type', style: _thStyle(theme))),
                SizedBox(
                  width: 160,
                  child: Text('Time', style: _thStyle(theme)),
                ),
              ],
            ),
          ),
          // Rows
          ...logs.asMap().entries.map((entry) {
            final index = entry.key;
            final log = entry.value;
            final color = _getActivityColor(log.activityType);
            final icon = _getActivityIcon(log.activityType);
            return _ActivityTableRow(
              log: log,
              color: color,
              icon: icon,
              formattedTime: _formatTimestamp(log.timestamp),
              isEven: index.isEven,
              theme: theme,
            );
          }),
        ],
      ),
    );
  }

  TextStyle _thStyle(ThemeData theme) {
    return theme.textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );
  }

  Widget _buildActivityTile(ThemeData theme, ActivityLog activity) {
    final color = _getActivityColor(activity.activityType);
    final icon = _getActivityIcon(activity.activityType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimestamp(activity.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Simplified: no technical labels
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No activity found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting filters or perform actions in the app',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: List.generate(6, (i) => i).map((_) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.borderMd,
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.borderSm,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadius.borderXs,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadius.borderXs,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError(ThemeData theme, Object error) {
    debugPrint('ActivityPage error: $error');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Unable to load activity logs',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
        return AppColors.success;
      case ActivityType.login:
        return AppColors.info;
      case ActivityType.studentUpdated:
      case ActivityType.subscriptionUpdated:
      case ActivityType.settingsChanged:
        return AppColors.warning;
      case ActivityType.studentDeleted:
      case ActivityType.subscriptionCancelled:
      case ActivityType.logout:
        return AppColors.error;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy – hh:mm a').format(timestamp);
  }

  String _friendlyDayLabel(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date); // Weekday name
    return DateFormat('MMM d, yyyy').format(date);
  }
}

class _ActivityTableRow extends StatefulWidget {
  const _ActivityTableRow({
    required this.log,
    required this.color,
    required this.icon,
    required this.formattedTime,
    required this.isEven,
    required this.theme,
  });

  final ActivityLog log;
  final Color color;
  final IconData icon;
  final String formattedTime;
  final bool isEven;
  final ThemeData theme;

  @override
  State<_ActivityTableRow> createState() => _ActivityTableRowState();
}

class _ActivityTableRowState extends State<_ActivityTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final typeName = widget.log.activityType.name
        .replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]}')
        .trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered
              ? theme.colorScheme.primary.withValues(alpha: 0.04)
              : (widget.isEven
                    ? Colors.transparent
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.15,
                      )),
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderSm,
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, color: widget.color, size: 16),
            ),
            const SizedBox(width: 12),
            // Description
            Expanded(
              flex: 4,
              child: Text(
                widget.log.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Type
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.08),
                  borderRadius: AppRadius.borderXs,
                ),
                child: Text(
                  typeName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Time
            SizedBox(
              width: 160,
              child: Text(
                widget.formattedTime,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
