import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';

import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_notifier.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:library_registration_app/presentation/widgets/common/modern_text_field.dart';
import 'package:library_registration_app/presentation/widgets/common/primary_button.dart';
import 'package:library_registration_app/presentation/widgets/common/typeahead_student_field.dart';
import 'package:library_registration_app/presentation/widgets/subscriptions/subscription_card.dart';
import 'package:library_registration_app/presentation/widgets/subscriptions/subscription_filters.dart';
import 'package:library_registration_app/presentation/widgets/subscriptions/subscription_timeline.dart';

String _getStatusDisplayName(SubscriptionStatus status) {
  switch (status) {
    case SubscriptionStatus.active:
      return 'Active';
    case SubscriptionStatus.expired:
      return 'Expired';
    case SubscriptionStatus.cancelled:
      return 'Cancelled';
    case SubscriptionStatus.pending:
      return 'Pending';
  }
}

class SubscriptionsPage extends ConsumerStatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  ConsumerState<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends ConsumerState<SubscriptionsPage> {
  bool _isTimelineView = false;
  SubscriptionStatus? _selectedStatus;
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();
  final List<Subscription> _paged = <Subscription>[];
  bool _isLoadingPage = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _pageSize = 50;

  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextPage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingPage) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = query);
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() => _isLoadingPage = true);
    try {
      final next = await ref.read(
        pagedSubscriptionsProvider((offset: _offset, limit: _pageSize)).future,
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
        message: 'Error loading subscriptions: $e',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(subscriptionsNotifierProvider.notifier).refresh();
    ref.invalidate(allStudentsProvider);
    setState(() {
      _paged.clear();
      _offset = 0;
      _hasMore = true;
      _selectedStatus = null;
      _searchQuery = '';
    });
    await _loadNextPage();
    if (mounted) {
      CustomNotification.show(context, message: 'Subscriptions refreshed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final studentsAsync = ref.watch(allStudentsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Gradient Background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                    ).copyWith(top: 8),
                    child: _buildModernHeader(theme),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                    ).copyWith(top: 16),
                    child: SubscriptionFilters(
                      selectedStatus: _selectedStatus,
                      searchQuery: _searchQuery,
                      onStatusChanged: (status) =>
                          setState(() => _selectedStatus = status),
                      onSearchChanged: _onSearchChanged,
                      onClearFilters: () {
                        setState(() {
                          _selectedStatus = null;
                          _searchQuery = '';
                        });
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                subscriptionsAsync.when(
                  data: (subscriptions) => studentsAsync.when(
                    data: (students) {
                      final hasActiveFilters =
                          _selectedStatus != null || _searchQuery.isNotEmpty;
                      final source = hasActiveFilters
                          ? subscriptions
                          : (_paged.isEmpty ? subscriptions : _paged);
                      final filtered = _filterSubscriptions(source, students);

                      if (filtered.isEmpty) {
                        if (_selectedStatus != null ||
                            _searchQuery.isNotEmpty) {
                          return SliverToBoxAdapter(
                            child: _buildNoFilteredResultsState(theme),
                          );
                        }
                        return SliverToBoxAdapter(
                          child: _buildEmptyState(theme),
                        );
                      }
                      final idToStudent = {for (final s in students) s.id: s};
                      return _isTimelineView
                          ? SliverToBoxAdapter(
                              child: SubscriptionTimeline(
                                subscriptions: filtered,
                                studentNamesById: idToStudent.map(
                                  (k, v) => MapEntry(k, v.fullName),
                                ),
                              ),
                            )
                          : _buildListView(filtered, students);
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SliverToBoxAdapter(
                      child: Center(child: Text('Error loading student data')),
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to load subscriptions',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            PrimaryButton(
                              text: 'Retry',
                              onPressed: () =>
                                  ref.invalidate(subscriptionsProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildAnimatedFAB(theme),
    );
  }

  Widget _buildAnimatedFAB(ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: FloatingActionButton(
            onPressed: () => _showAddSubscriptionDialog(context),
            backgroundColor: theme.colorScheme.primary,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                    theme.colorScheme.primary,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscriptions',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage student access and payments',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () =>
                  setState(() => _isTimelineView = !_isTimelineView),
              icon: Icon(
                _isTimelineView
                    ? Icons.view_list_rounded
                    : Icons.timeline_rounded,
              ),
              tooltip: _isTimelineView ? 'List View' : 'Timeline View',
            ),
          ],
        ),
      ],
    );
  }

  List<Subscription> _filterSubscriptions(
    List<Subscription> subscriptions,
    List<Student> students,
  ) {
    var filtered = subscriptions;
    final idToStudent = {for (final s in students) s.id: s};

    if (_selectedStatus != null) {
      filtered = filtered.where((s) {
        switch (_selectedStatus!) {
          case SubscriptionStatus.active:
            return s.status == SubscriptionStatus.active && !s.isExpired;
          case SubscriptionStatus.expired:
            return s.status == SubscriptionStatus.expired || s.isExpired;
          case SubscriptionStatus.pending:
            return s.status == SubscriptionStatus.pending;
          case SubscriptionStatus.cancelled:
            return s.status == SubscriptionStatus.cancelled;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty && _searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((subscription) {
        final planMatch = subscription.planName.toLowerCase().contains(query);
        final amountMatch = subscription.amount.toString().contains(query);
        final idMatch = subscription.id.toLowerCase().contains(query);
        final student = idToStudent[subscription.studentId];
        if (student == null) return planMatch || amountMatch || idMatch;

        final studentMatch =
            student.fullName.toLowerCase().contains(query) ||
            student.email.toLowerCase().contains(query) ||
            (student.phone?.toLowerCase().contains(query) ?? false) ||
            (student.seatNumber?.toLowerCase().contains(query) ?? false);
        return planMatch || amountMatch || idMatch || studentMatch;
      }).toList();
    }
    return filtered;
  }

  Widget _buildListView(
    List<Subscription> subscriptions,
    List<Student> students,
  ) {
    final idToStudent = {for (final s in students) s.id: s};
    final padding = ResponsiveUtils.getResponsivePadding(context);

    // Grid Logic
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return SliverPadding(
        padding: padding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final subscription = subscriptions[index];
            final student = idToStudent[subscription.studentId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SubscriptionCard(
                subscription: subscription,
                studentName: student?.fullName,
                studentAvatarPath: student?.profileImagePath,
                studentInitials: student?.initials,
                onTap: () =>
                    context.go('/students/details/${subscription.studentId}'),
                onEdit: () => _showEditSubscriptionDialog(subscription),
                onCancel: () => _cancelSubscription(subscription),
                onRenew: () => _renewSubscription(subscription),
                onDelete: () => _confirmDelete(subscription),
              ),
            );
          }, childCount: subscriptions.length),
        ),
      );
    } else {
      final int crossAxisCount = (screenWidth / 360).floor().clamp(2, 4);
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final subscription = subscriptions[index];
            final student = idToStudent[subscription.studentId];
            return SubscriptionCard(
              subscription: subscription,
              studentName: student?.fullName,
              studentAvatarPath: student?.profileImagePath,
              studentInitials: student?.initials,
              onTap: () =>
                  context.go('/students/details/${subscription.studentId}'),
              onEdit: () => _showEditSubscriptionDialog(subscription),
              onCancel: () => _cancelSubscription(subscription),
              onRenew: () => _renewSubscription(subscription),
              onDelete: () => _confirmDelete(subscription),
            );
          }, childCount: subscriptions.length),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_membership_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No subscriptions found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first subscription to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilteredResultsState(ThemeData theme) {
    return Padding(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No matches found', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _selectedStatus = null;
                  _searchQuery = '';
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    showAppBottomSheet<void>(
      context,
      builder: (context) => _AddSubscriptionSheet(onSaved: _onRefresh),
    );
  }

  void _showEditSubscriptionDialog(Subscription subscription) {
    showAppBottomSheet<void>(
      context,
      builder: (context) => _EditSubscriptionSheet(
        subscription: subscription,
        onSaved: _onRefresh,
      ),
    );
  }

  // --- Actions ---

  Future<void> _confirmDelete(Subscription s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subscription?'),
        content: Text('Permanently delete "${s.planName}" subscription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(subscriptionsNotifierProvider.notifier)
            .deleteSubscription(s.id);
        await _onRefresh();
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Subscription deleted',
            type: NotificationType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Delete failed: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _cancelSubscription(Subscription subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: Text(
          'Are you sure you want to cancel the subscription for ${subscription.planName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(subscriptionsNotifierProvider.notifier)
            .cancelSubscription(subscription.id);
        await _onRefresh();
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Subscription cancelled',
            type: NotificationType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Error: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _renewSubscription(Subscription subscription) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: subscription.endDate.isBefore(now)
          ? now.add(const Duration(days: 30))
          : subscription.endDate.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Select New End Date',
    );
    if (pickedDate == null) return;

    final amountCtrl = TextEditingController(
      text: subscription.amount.toStringAsFixed(2),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renew Subscription'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Renewal Amount',
            prefixIcon: Icon(Icons.currency_rupee),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amountCtrl.text.trim());
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (amount != null) {
      try {
        await ref
            .read(subscriptionsNotifierProvider.notifier)
            .renewSubscription(subscription.id, pickedDate, amount);
        await _onRefresh();
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Renowed successfully',
            type: NotificationType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Renew failed: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }
}

// --- Sheets ---

class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet({required this.onSaved});
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  DateTime? _start;
  DateTime? _end;
  final SubscriptionStatus _status = SubscriptionStatus.active;
  Student? _selectedStudent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Staggered animation setup could be here, but using simple entrance for now
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 0,
        right: 0,
        top: 0, // Reset top padding as we'll use a container
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium Header with Gradient/Image or just Clean Design
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_card,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Subscription',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Add a new student plan',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypeaheadStudentField(
                      initial: _selectedStudent,
                      onSelected: (s) {
                        setState(() {
                          _selectedStudent = s;
                          if (s != null) _studentIdCtrl.text = s.id;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ModernTextField(
                      controller: _planCtrl,
                      label: 'Plan Name',
                      icon: Icons.badge_outlined,
                      isRequired: true,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    ModernTextField(
                      controller: _amountCtrl,
                      label: 'Amount (₹)',
                      icon: Icons.currency_rupee,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      isRequired: true,
                      validator: (v) => double.tryParse(v ?? '') == null
                          ? 'Invalid amount'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'DURATION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => _start = d);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Start Date',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _start == null
                                        ? 'Select'
                                        : '${_start!.day}/${_start!.month}/${_start!.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _start ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => _end = d);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'End Date',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _end == null
                                        ? 'Select'
                                        : '${_end!.day}/${_end!.month}/${_end!.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Create Subscription',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null || _end == null) {
      CustomNotification.show(
        context,
        message: 'Dates are required',
        type: NotificationType.error,
      );
      return;
    }
    if (_selectedStudent == null) {
      CustomNotification.show(
        context,
        message: 'Select a student',
        type: NotificationType.error,
      );
      return;
    }

    try {
      await ref
          .read(subscriptionsNotifierProvider.notifier)
          .createSubscription(
            studentId: _selectedStudent!.id,
            planName: _planCtrl.text.trim(),
            startDate: _start!,
            endDate: _end!,
            amount: double.parse(_amountCtrl.text.trim()),
            status: _status,
          );
      if (mounted) {
        Navigator.pop(context);
        await widget.onSaved();
        CustomNotification.show(
          context,
          message: 'Created successfully',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Failed: $e',
          type: NotificationType.error,
        );
      }
    }
  }
}

class _EditSubscriptionSheet extends ConsumerStatefulWidget {
  const _EditSubscriptionSheet({
    required this.subscription,
    required this.onSaved,
  });
  final Subscription subscription;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_EditSubscriptionSheet> createState() =>
      _EditSubscriptionSheetState();
}

class _EditSubscriptionSheetState
    extends ConsumerState<_EditSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _planCtrl;
  late TextEditingController _amountCtrl;
  late SubscriptionStatus _status;

  @override
  void initState() {
    super.initState();
    _planCtrl = TextEditingController(text: widget.subscription.planName);
    _amountCtrl = TextEditingController(
      text: widget.subscription.amount.toString(),
    );
    _status = widget.subscription.status;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Staggered animation setup could be here, but using simple entrance for now
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 0,
        right: 0,
        top: 0, // Reset top padding as we'll use a container
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium Header with Gradient/Image or just Clean Design
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_note,
                          color: theme.colorScheme.tertiary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Subscription',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Update plan details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModernTextField(
                      controller: _planCtrl,
                      label: 'Plan Name',
                      icon: Icons.badge_outlined,
                      isRequired: true,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    ModernTextField(
                      controller: _amountCtrl,
                      label: 'Amount (₹)',
                      icon: Icons.currency_rupee,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      isRequired: true,
                      validator: (v) => double.tryParse(v ?? '') == null
                          ? 'Invalid amount'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<SubscriptionStatus>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      items: SubscriptionStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                _getStatusDisplayName(s),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final updated = widget.subscription.copyWith(
        planName: _planCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.trim()),
        status: _status,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(subscriptionsNotifierProvider.notifier)
          .updateSubscription(updated);
      await widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        CustomNotification.show(
          context,
          message: 'Updated successfully',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Update failed: $e',
          type: NotificationType.error,
        );
      }
    }
  }
}
