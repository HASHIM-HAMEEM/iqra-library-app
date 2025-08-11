import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/students/students_notifier.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
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
        _showSnackBar('Error searching students: $e', isError: true);
      }
    }
  }

  List<Student> _getFilteredStudents(
    List<Student> students,
    List<Subscription> subscriptions,
  ) {
    final now = DateTime.now();
    final studentIdToSubs = <String, List<Subscription>>{};
    for (final sub in subscriptions) {
      (studentIdToSubs[sub.studentId] ??= []).add(sub);
    }
    bool hasActive(String studentId) {
      final subs = studentIdToSubs[studentId];
      if (subs == null) return false;
      return subs.any(
        (s) => s.status == SubscriptionStatus.active && s.endDate.isAfter(now),
      );
    }

    bool hasExpired(String studentId) {
      final subs = studentIdToSubs[studentId];
      if (subs == null) return false;
      return subs.any(
        (s) =>
            s.status == SubscriptionStatus.expired || s.endDate.isBefore(now),
      );
    }

    var filtered = students;

    switch (_activeFilter) {
      case 'Active':
        filtered = students.where((s) => hasActive(s.id)).toList();
      case 'Expired':
        filtered = students
            .where((s) => !hasActive(s.id) && hasExpired(s.id))
            .toList();
      case 'New':
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        filtered = students
            .where((s) => s.createdAt.isAfter(thirtyDaysAgo))
            .toList();
      default:
        filtered = students;
    }

    switch (_sortBy) {
      case 'Name':
        filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
      case 'Email':
        filtered.sort((a, b) => a.email.compareTo(b.email));
      case 'Date':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'Age':
        filtered.sort((a, b) => a.age.compareTo(b.age));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
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

          // Students List
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveUtils.getResponsivePadding(
                context,
              ).copyWith(top: 16, bottom: 24),
              child: _buildStudentsList(studentsAsync),
            ),
          ),
        ],
      ),
      floatingActionButton:
          Listener(
            onPointerDown: (_) => setState(() {}),
            onPointerUp: (_) => setState(() {}),
            child: FloatingActionButton(
              onPressed: () {
                context.go('/students/add');
                _showSnackBar('Opening Add Student form');
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.person_add_rounded),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.04, 1.04),
                  duration: 1400.ms,
                  curve: Curves.easeInOut,
                )
                .fadeIn(duration: 300.ms),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _showFiltersSheet,
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Filters & Sort',
            ),
            IconButton(
              onPressed: () {
                ref.read(studentsNotifierProvider.notifier).refresh();
                _showSnackBar('Refreshing students list');
              },
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search students by name, email, or phone...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _performSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _performSearch(value);
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
              'Filters & Sort',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Status',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['All', 'Active', 'Expired', 'New'].map((option) {
                final selected = _stagedFilter == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (_) => setState(() => _stagedFilter = option),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Sort by',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Name', 'Email', 'Date', 'Age'].map((option) {
                final selected = _stagedSortBy == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (_) => setState(() => _stagedSortBy = option),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _stagedFilter = 'All';
                      _stagedSortBy = 'Name';
                    });
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _activeFilter = _stagedFilter;
                      _sortBy = _stagedSortBy;
                    });
                    Navigator.of(ctx).pop();
                    _showSnackBar('Applied filters');
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildStudentsList(AsyncValue<List<Student>> studentsAsync) {
    final subsAsync = ref.watch(subscriptionsProvider);
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchQuery.isNotEmpty) {
      return _buildStudentsListView(_searchResults);
    }

    return studentsAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return _buildEmptyState();
        }
        return subsAsync.when(
          data: (subs) {
            final filteredStudents = _getFilteredStudents(students, subs);
            if (filteredStudents.isEmpty) return _buildNoResultsState();
            return _buildStudentsListView(filteredStudents);
          },
          loading: _buildLoadingState,
          error: (e, _) => _buildErrorState(e),
        );
      },
      loading: _buildLoadingState,
      error: (error, stack) => _buildErrorState(error),
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

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Center(
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
    );
  }

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
              'Error loading students',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(studentsNotifierProvider.notifier).refresh();
                _showSnackBar('Retrying...');
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

  Widget _buildStudentsListView(List<Student> students) {
    if (students.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(
                Icons.people_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${students.length} student${students.length == 1 ? '' : 's'} found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (ResponsiveUtils.isMobile(context)) ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: students.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildModernStudentCard(students[index]),
              ) else GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveUtils.isTablet(context) ? 2 : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: ResponsiveUtils.isTablet(context) ? 2.2 : 2.6,
                ),
                itemCount: students.length,
                itemBuilder: (context, index) =>
                    _buildModernStudentCard(students[index]),
              ),
      ],
    );
  }

  Widget _buildModernStudentCard(Student student) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shadowColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/students/details/${student.id}');
            _showSnackBar("Opening ${student.fullName}'s profile");
          },
          onLongPress: () {
            _showDeleteConfirmation(student);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildStudentAvatar(student, theme, size: 48),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Age: ${student.age}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (student.seatNumber != null && student.seatNumber!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Seat ${student.seatNumber!}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student.email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (student.phone?.isNotEmpty == true) ...[
                            const SizedBox(width: 8),
                            Text('•',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                student.phone!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(Student student, ThemeData theme, {double size = 60}) {
    // Check if student has a profile image path
    if (student.profileImagePath?.isNotEmpty == true) {
      try {
        final file = File(student.profileImagePath!);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to IQRA logo if image fails to load
              return _buildIqraLogoPlaceholder(theme);
            },
          );
        }
      } catch (e) {
        // If any error occurs, fallback to IQRA logo
      }
    }

    // Fallback to IQRA logo
    return _buildIqraLogoPlaceholder(theme);
  }

  Widget _buildIqraLogoPlaceholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.school_outlined, // Using school icon as IQRA logo placeholder
          size: 30,
          color: theme.colorScheme.onPrimaryContainer,
        ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${student.fullName} deleted successfully',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting student: $e')),
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
