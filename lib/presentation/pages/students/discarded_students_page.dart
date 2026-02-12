import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/app_colors.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';

class DiscardedStudentsPage extends ConsumerStatefulWidget {
  const DiscardedStudentsPage({super.key});

  @override
  ConsumerState<DiscardedStudentsPage> createState() =>
      _DiscardedStudentsPageState();
}

class _DiscardedStudentsPageState extends ConsumerState<DiscardedStudentsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Student> _paged = <Student>[];
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
        pagedDiscardedStudentsProvider((
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
        message: 'Error loading discarded students: $e',
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
    ref.invalidate(pagedDiscardedStudentsProvider);
    await _loadNextPage();
  }

  Future<void> _restore(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore student?'),
        content: Text(
          'Restore "${student.fullName}" back to the Students list?',
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
      await ref
          .read(studentsNotifierProvider.notifier)
          .restoreStudent(student.id);
      if (!mounted) return;
      setState(() => _paged.removeWhere((s) => s.id == student.id));
      CustomNotification.show(
        context,
        message: 'Student restored',
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

  Future<void> _deletePermanently(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          'This will permanently delete "${student.fullName}" and their subscriptions.\n\nThis cannot be undone.',
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
      await ref
          .read(studentsNotifierProvider.notifier)
          .deleteStudent(student.id, hard: true);
      if (!mounted) return;
      setState(() => _paged.removeWhere((s) => s.id == student.id));
      CustomNotification.show(
        context,
        message: 'Student permanently deleted',
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

    final filtered = _query.isEmpty
        ? _paged
        : _paged.where((s) {
            final q = _query;
            return s.fullName.toLowerCase().contains(q) ||
                s.email.toLowerCase().contains(q) ||
                (s.phone?.toLowerCase().contains(q) ?? false) ||
                (s.seatNumber?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Discarded Students'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/students'),
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
                  'Deleted students are kept here until you restore them or delete them permanently.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search discarded students...',
                  ),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty && !_isLoadingPage)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No discarded students',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  ...filtered.map((student) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: AsyncAvatar(
                          imagePath: student.profileImagePath,
                          initials: student.initials,
                          size: 44,
                          fallbackIcon: Icons.person_rounded,
                        ),
                        title: Text(student.fullName),
                        subtitle: Text(student.email),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Restore',
                              onPressed: () => _restore(student),
                              icon: const Icon(Icons.restore_rounded),
                            ),
                            IconButton(
                              tooltip: 'Delete permanently',
                              onPressed: () => _deletePermanently(student),
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
                        'All discarded students loaded',
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
