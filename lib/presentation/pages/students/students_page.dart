import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/async_avatar.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<Student> _searchResults = [];
  String _activeFilter = 'All';
  String _sortBy = 'Name';
  String _stagedFilter = 'All';
  String _stagedSortBy = 'Name';
  Timer? _debounceTimer;

  // Cache for subscription status to avoid repeated calculations
  final Map<String, bool> _activeStatusCache = {};
  final Map<String, bool> _expiredStatusCache = {};
  DateTime? _lastCacheUpdate;

  // Pagination state
  final int _pageSize = 50;
  final ScrollController _scrollController = ScrollController();
  final List<Student> _pagedStudents = [];
  bool _isLoadingPage = false;
  bool _hasMorePages = true;
  int _currentOffset = 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    // Reset pagination and refresh data
    setState(() {
      _pagedStudents.clear();
      _currentOffset = 0;
      _hasMorePages = true;
      _isLoadingPage = false;
    });
    await ref.read(studentsNotifierProvider.notifier).refresh();
    ref.invalidate(subscriptionsProvider);
    await _loadNextPage();
    if (!mounted) return;
    _showNotification('Students list refreshed');
  }

  void _showNotification(String message, {bool isError = false}) {
    CustomNotification.show(
      context,
      message: message,
      type: isError ? NotificationType.error : NotificationType.success,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _debounceTimer?.cancel();
      final text = _searchController.text;
      if (text.isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
          _searchQuery = '';
        });
      } else {
        setState(() {
          _searchQuery = text;
        });
        _debounceTimer = Timer(const Duration(milliseconds: 200), () {
          _performSearch(text);
        });
      }
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNextPage();
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await ref
          .read(studentsNotifierProvider.notifier)
          .searchStudents(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      if (mounted) {
        _showNotification('Error searching students: $e', isError: true);
      }
    }
  }

  void _onScroll() {
    if (!_hasMorePages || _isLoadingPage) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingPage || !_hasMorePages) return;
    setState(() {
      _isLoadingPage = true;
    });
    try {
      final next = await ref.read(
        pagedStudentsProvider((
          offset: _currentOffset,
          limit: _pageSize,
        )).future,
      );
      if (!mounted) return;
      setState(() {
        _pagedStudents.addAll(next);
        _currentOffset += next.length;
        _hasMorePages = next.length == _pageSize;
        _isLoadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPage = false;
      });
      _showNotification('Error loading students: $e', isError: true);
    }
  }

  List<Student> _getFilteredStudents(
    List<Student> students,
    List<Subscription> subscriptions,
  ) {
    final now = DateTime.now();

    // Check if cache needs to be updated (every 5 minutes or if empty)
    final shouldUpdateCache =
        _lastCacheUpdate == null ||
        now.difference(_lastCacheUpdate!).inMinutes > 5 ||
        _activeStatusCache.isEmpty;

    if (shouldUpdateCache) {
      _updateSubscriptionCache(subscriptions, now);
      _lastCacheUpdate = now;
    }

    // Pre-filter students based on active filter to reduce iterations
    List<Student> filtered;

    switch (_activeFilter) {
      case 'Active':
        filtered = students
            .where((s) => _activeStatusCache[s.id] ?? false)
            .toList();
      case 'Expired':
        filtered = students
            .where(
              (s) =>
                  !(_activeStatusCache[s.id] ?? false) &&
                  (_expiredStatusCache[s.id] ?? false),
            )
            .toList();
      case 'New':
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        filtered = students
            .where((s) => s.createdAt.isAfter(thirtyDaysAgo))
            .toList();
      default:
        filtered = List.from(
          students,
        ); // Create a copy to avoid modifying original
    }

    // Sort the filtered list
    _sortStudents(filtered);

    return filtered;
  }

  void _updateSubscriptionCache(
    List<Subscription> subscriptions,
    DateTime now,
  ) {
    _activeStatusCache.clear();
    _expiredStatusCache.clear();

    // Group subscriptions by student ID for efficient lookup
    final studentIdToSubs = <String, List<Subscription>>{};
    for (final sub in subscriptions) {
      (studentIdToSubs[sub.studentId] ??= []).add(sub);
    }

    // Calculate status for each student
    for (final entry in studentIdToSubs.entries) {
      final studentId = entry.key;
      final subs = entry.value;

      var hasActive = false;
      var hasExpired = false;

      for (final sub in subs) {
        if (sub.status == SubscriptionStatus.active &&
            sub.endDate.isAfter(now)) {
          hasActive = true;
        }
        if (sub.status == SubscriptionStatus.expired ||
            sub.endDate.isBefore(now)) {
          hasExpired = true;
        }

        // Early exit if both statuses are found
        if (hasActive && hasExpired) break;
      }

      _activeStatusCache[studentId] = hasActive;
      _expiredStatusCache[studentId] = hasExpired;
    }
  }

  void _clearSubscriptionCache() {
    _activeStatusCache.clear();
    _expiredStatusCache.clear();
    _lastCacheUpdate = null;
  }

  void _sortStudents(List<Student> students) {
    switch (_sortBy) {
      case 'Name':
        students.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
      case 'Email':
        students.sort(
          (a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        );
      case 'Date':
        students.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'Age':
        students.sort((a, b) => a.age.compareTo(b.age));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subsAsync = ref.watch(subscriptionsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
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

            // Search and Filter Section
            SliverToBoxAdapter(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(
                  context,
                ).copyWith(top: 16),
                child: _buildSearchSection(theme),
              ),
            ),

            // Chips moved into filter sheet (tune icon)

            // Students List (slivers)
            ..._buildStudentsSlivers(subsAsync),
          ],
        ),
      ),
      floatingActionButton: Listener(
        onPointerDown: (_) => setState(() {}),
        onPointerUp: (_) => setState(() {}),
        child: FloatingActionButton(
          onPressed: () {
            context.go('/students/add');
            _showNotification('Opening Add Student form');
          },
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: const Icon(Icons.person_add_rounded),
        ),
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Students',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Manage student records and information',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _showFiltersSheet,
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Filters & Sort',
        ),
      ],
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search students...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 16,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.clear_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _performSearch('');
                    },
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  // Chips moved to bottom sheet
  void _showFiltersSheet() {
    _stagedFilter = _activeFilter;
    _stagedSortBy = _sortBy;
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter & Sort',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _stagedFilter = 'All';
                            _stagedSortBy = 'Name';
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status Filter
                  Text(
                    'STATUS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ['All', 'Active', 'Expired', 'New'].map((option) {
                      final selected = _stagedFilter == option;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  ),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                setSheetState(() => _stagedFilter = option),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected) ...[
                                    Icon(
                                      Icons.check,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    option,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: selected
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Sort By Filter
                  Text(
                    'SORT BY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ['Name', 'Email', 'Date', 'Age'].map((option) {
                      final selected = _stagedSortBy == option;
                      return InkWell(
                        onTap: () =>
                            setSheetState(() => _stagedSortBy = option),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.secondary
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            option,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? theme.colorScheme.onSecondaryContainer
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _activeFilter = _stagedFilter;
                          _sortBy = _stagedSortBy;
                          // Clear cache when filters change to ensure fresh data
                          _clearSubscriptionCache();
                        });
                        Navigator.of(ctx).pop();
                        _showNotification('Filters applied successfully');
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Deprecated list builder (replaced by slivers)

  List<Widget> _buildStudentsSlivers(AsyncValue<List<Subscription>> subsAsync) {
    if (_isSearching) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ];
    }
    if (_searchQuery.isNotEmpty) {
      return [
        SliverPadding(
          padding: ResponsiveUtils.getResponsivePadding(
            context,
          ).copyWith(top: 16, bottom: 24),
          sliver: _buildStudentsSliverListOrGrid(_searchResults),
        ),
      ];
    }
    // Paged mode using _pagedStudents
    return [
      subsAsync.when(
        data: (subs) {
          if (_pagedStudents.isEmpty && _isLoadingPage) {
            return _buildLoadingSliver();
          }
          if (_pagedStudents.isEmpty) {
            return SliverToBoxAdapter(child: _buildEmptyState());
          }
          final filtered = _getFilteredStudents(_pagedStudents, subs);
          if (filtered.isEmpty) {
            return SliverToBoxAdapter(child: _buildNoResultsState());
          }
          return SliverPadding(
            padding: ResponsiveUtils.getResponsivePadding(
              context,
            ).copyWith(top: 16, bottom: 8),
            sliver: _buildStudentsSliverListOrGrid(filtered),
          );
        },
        loading: _buildLoadingSliver,
        error: (e, _) => SliverToBoxAdapter(child: _buildErrorState(e)),
      ),
      SliverToBoxAdapter(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _isLoadingPage
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (!_hasMorePages
                        ? Text(
                            'All students loaded',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          )
                        : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildStudentsSliverListOrGrid(List<Student> students) {
    if (ResponsiveUtils.isMobile(context)) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RepaintBoundary(
              child: _buildModernStudentCard(students[index]),
            ),
          ),
          childCount: students.length,
        ),
      );
    }
    final columns = ResponsiveUtils.isTablet(context) ? 2 : 3;
    final aspect = ResponsiveUtils.isTablet(context) ? 2.2 : 2.6;
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) =>
            RepaintBoundary(child: _buildModernStudentCard(students[index])),
        childCount: students.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspect,
      ),
    );
  }

  Widget _buildLoadingSliver() {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading students...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height * 0.5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No students yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Add your first student to get started with managing your library.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter criteria',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Deprecated: replaced by _buildLoadingSliver

  Widget _buildErrorState(Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load students',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(studentsNotifierProvider.notifier).refresh();
                _showNotification('Retrying...');
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Deprecated: replaced by _buildStudentsSliverListOrGrid

  Widget _buildModernStudentCard(Student student) {
    final theme = Theme.of(context);

    // Get subscription status for this student
    final hasActiveSubscription = _activeStatusCache[student.id] ?? false;
    final hasExpiredSubscription = _expiredStatusCache[student.id] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/students/details/${student.id}');
            // _showNotification("Opening ${student.fullName}'s profile");
          },
          onLongPress: () {
            _showDeleteConfirmation(student);
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with Status Ring
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasActiveSubscription
                          ? const Color(0xFF10B981) // Success Green
                          : (hasExpiredSubscription
                                ? theme.colorScheme.error
                                : Colors.transparent),
                      width: 2,
                    ),
                  ),
                  child: _buildStudentAvatar(student, theme, size: 52),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        student.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              student.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods like _buildSubscriptionStatusBadge removed as status is now in avatar ring

  Widget _buildStudentAvatar(
    Student student,
    ThemeData theme, {
    double size = 48,
  }) {
    return ClipOval(
      child: AsyncAvatar(
        imagePath: student.profileImagePath,
        initials: student.initials,
        size: size,
        fallbackIcon: Icons.person_rounded,
      ),
    );
  }

  void _showDeleteConfirmation(Student student) {
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Student',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Are you sure you want to delete ${student.fullName}?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ref
                          .read(studentsNotifierProvider.notifier)
                          .deleteStudent(student.id);
                      if (mounted) {
                        CustomNotification.show(
                          context,
                          message: '${student.fullName} deleted successfully',
                          type: NotificationType.success,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        CustomNotification.show(
                          context,
                          message: 'Error deleting student: $e',
                          type: NotificationType.error,
                        );
                      }
                    }
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
