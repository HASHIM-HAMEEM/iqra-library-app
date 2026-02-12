import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/app_colors.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';

class DiscardedSubscriptionsPage extends ConsumerStatefulWidget {
  const DiscardedSubscriptionsPage({super.key});

  @override
  ConsumerState<DiscardedSubscriptionsPage> createState() =>
      _DiscardedSubscriptionsPageState();
}

class _DiscardedSubscriptionsPageState
    extends ConsumerState<DiscardedSubscriptionsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Subscription> _paged = <Subscription>[];
  bool _isLoadingPage = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _pageSize = 50;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextPage());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingPage) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final text = _searchCtrl.text;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = text.trim().toLowerCase());
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() => _isLoadingPage = true);
    try {
      final next = await ref.read(
        pagedDiscardedSubscriptionsProvider((
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
      CustomNotification.show(
        context,
        message: 'Error loading discarded subscriptions: $e',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _paged.clear();
      _offset = 0;
      _hasMore = true;
      _isLoadingPage = false;
    });
    ref.invalidate(pagedDiscardedSubscriptionsProvider);
    await _loadNextPage();
  }

  Future<void> _restoreSubscription(
    Subscription sub, {
    required bool canRestore,
  }) async {
    if (!canRestore) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore subscription?'),
        content: Text(
          'Restore "${sub.planName}" subscription back to the Subscriptions list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.restoreSubscription(sub.id);
      if (!mounted) return;
      setState(() => _paged.removeWhere((s) => s.id == sub.id));
      ref.invalidate(subscriptionsProvider);
      CustomNotification.show(
        context,
        message: 'Subscription restored',
        type: NotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Restore failed: $e',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _deletePermanently(Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          'This will permanently delete "${sub.planName}" subscription.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.deleteSubscription(sub.id, hard: true);
      if (!mounted) return;
      setState(() => _paged.removeWhere((s) => s.id == sub.id));
      ref.invalidate(subscriptionsProvider);
      CustomNotification.show(
        context,
        message: 'Subscription permanently deleted',
        type: NotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Delete failed: $e',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _trashOrphan(Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to trash?'),
        content: Text(
          'This subscription belongs to a deleted student.\n\nMove "${sub.planName}" to trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.deleteSubscription(sub.id);
      if (!mounted) return;
      ref.invalidate(subscriptionsProvider);
      CustomNotification.show(
        context,
        message: 'Moved to trash',
        type: NotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Failed: $e',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _deleteOrphanPermanently(Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          'This will permanently delete "${sub.planName}" subscription.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.deleteSubscription(sub.id, hard: true);
      if (!mounted) return;
      ref.invalidate(subscriptionsProvider);
      CustomNotification.show(
        context,
        message: 'Subscription permanently deleted',
        type: NotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomNotification.show(
        context,
        message: 'Delete failed: $e',
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final dateFmt = DateFormat('dd MMM yyyy');

    final activeStudentsAsync = ref.watch(studentsProvider);
    final activeSubsAsync = ref.watch(subscriptionsProvider);

    final activeStudents = activeStudentsAsync.valueOrNull ?? <Student>[];
    final activeStudentIds = {for (final s in activeStudents) s.id};

    final activeSubs = activeSubsAsync.valueOrNull ?? <Subscription>[];
    final orphanActiveSubs =
        activeSubs
            .where((s) => !activeStudentIds.contains(s.studentId))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final filteredDiscarded = _query.isEmpty
        ? _paged
        : _paged.where((s) {
            final q = _query;
            return s.planName.toLowerCase().contains(q) ||
                s.studentId.toLowerCase().contains(q) ||
                s.status.name.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Discarded Subscriptions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/subscriptions'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.getMaxContentWidth(context),
            ),
            child: ListView(
              controller: _scrollController,
              padding: padding.copyWith(top: 12, bottom: 24),
              children: [
                Text(
                  'Deleted subscriptions are kept here until you restore them or delete them permanently.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search discarded subscriptions...',
                  ),
                ),
                if (orphanActiveSubs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Orphaned (student deleted)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...orphanActiveSubs.take(50).map((sub) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(sub.planName),
                        subtitle: Text('Student: ${sub.studentId}'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Move to trash',
                              onPressed: () => _trashOrphan(sub),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                            IconButton(
                              tooltip: 'Delete permanently',
                              onPressed: () => _deleteOrphanPermanently(sub),
                              icon: Icon(
                                Icons.delete_forever_rounded,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                if (filteredDiscarded.isEmpty && !_isLoadingPage)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No discarded subscriptions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredDiscarded.map((sub) {
                    final canRestore = activeStudentIds.contains(sub.studentId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(sub.planName),
                        subtitle: Text(
                          '${dateFmt.format(sub.startDate)} – ${dateFmt.format(sub.endDate)}'
                          '\nStudent: ${sub.studentId}${canRestore ? '' : ' (student deleted)'}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: canRestore
                                  ? 'Restore'
                                  : 'Restore student first',
                              onPressed: canRestore
                                  ? () => _restoreSubscription(
                                      sub,
                                      canRestore: canRestore,
                                    )
                                  : null,
                              icon: const Icon(Icons.restore_rounded),
                            ),
                            IconButton(
                              tooltip: 'Delete permanently',
                              onPressed: () => _deletePermanently(sub),
                              icon: Icon(
                                Icons.delete_forever_rounded,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (_isLoadingPage)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (!_hasMore && _paged.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'All discarded subscriptions loaded',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
