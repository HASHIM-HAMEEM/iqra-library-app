import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/utils/error_mapper.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/core/utils/telemetry_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_notifier.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/primary_button.dart';
import 'package:library_registration_app/presentation/widgets/common/typeahead_student_field.dart';
import 'package:library_registration_app/presentation/widgets/subscriptions/subscription_card.dart';
import 'package:library_registration_app/presentation/widgets/subscriptions/subscription_filters.dart';
import 'package:library_registration_app/presentation/widgets/subscriptions/subscription_timeline.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';

// Removed fixed plans and amounts; admin chooses plan name and amount freely.

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
  String? _overlapBannerMessage;
  
  // Pagination
  final ScrollController _scrollController = ScrollController();
  final List<Subscription> _paged = [];
  bool _isLoadingPage = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _pageSize = 50;

  Future<void> _onRefresh() async {
    // Refresh subscriptions and students data
    await ref.read(subscriptionsNotifierProvider.notifier).refresh();
    ref.invalidate(allStudentsProvider);
    // Reset pagination
    setState(() {
      _paged.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadNextPage();
    if (!mounted) return;
    CustomNotification.show(
      context,
      message: 'Subscriptions refreshed',
      type: NotificationType.success,
    );
  }

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
      final next = await ref.read(pagedSubscriptionsProvider((offset: _offset, limit: _pageSize)).future);
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
      CustomNotification.show(context, message: 'Error loading subscriptions: $e', type: NotificationType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final studentsAsync = ref.watch(allStudentsProvider);
    
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

            // Filters Section
            SliverToBoxAdapter(
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(
                  context,
                ).copyWith(top: 16),
                child: SubscriptionFilters(
                  selectedStatus: _selectedStatus,
                  searchQuery: _searchQuery,
                  onStatusChanged: (status) {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  onSearchChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                  },
                ),
              ),
            ),

            // Content spacer
            SliverToBoxAdapter(
              child: SizedBox(
                height: ResponsiveUtils.getResponsivePadding(context).top,
              ),
            ),

            // Content
            subscriptionsAsync.when(
              data: (subscriptions) => studentsAsync.when(
                data: (students) {
                  final source = _paged.isEmpty ? subscriptions : _paged;
                  final filteredSubscriptions = _filterSubscriptions(
                    source,
                    students,
                  );
                  if (filteredSubscriptions.isEmpty) {
                    return SliverToBoxAdapter(child: _buildEmptyState(theme));
                  }
                  final idToStudent = {for (final s in students) s.id: s};
                  return _isTimelineView
                      ? SliverToBoxAdapter(
                          child: SubscriptionTimeline(
                            subscriptions: filteredSubscriptions,
                            studentNamesById: idToStudent.map(
                              (k, v) => MapEntry(k, v.fullName),
                            ),
                          ),
                        )
                      : _buildListView(filteredSubscriptions, students);
                },
               loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SliverToBoxAdapter(
                  child: Center(child: Text('Error loading students')),
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading subscriptions',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: 'Retry',
                        onPressed: () => ref.invalidate(subscriptionsProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubscriptionDialog(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add_outlined),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.04, 1.04),
            duration: 1400.ms,
            curve: Curves.easeInOut,
          )
          .fadeIn(duration: 300.ms),
    );
  }

  Future<void> _confirmDelete(Subscription s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subscription?'),
        content: Text('This will permanently delete the "${s.planName}" subscription.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      try {
        await ref.read(subscriptionsNotifierProvider.notifier).deleteSubscription(s.id);
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
            message: 'Error deleting subscription: $e',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscriptions',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Manage subscription plans and payments',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () =>
              setState(() => _isTimelineView = !_isTimelineView),
          icon: Icon(
            _isTimelineView
                ? Icons.view_list_outlined
                : Icons.timeline_outlined,
            color: theme.colorScheme.onSurface,
          ),
          tooltip: _isTimelineView ? 'List View' : 'Timeline View',
        ),
      ],
    );
  }

  List<Subscription> _filterSubscriptions(
    List<Subscription> subscriptions,
    List<Student> students,
  ) {
    var filtered = subscriptions;
    
    // Filter by status
    if (_selectedStatus != null) {
      filtered = filtered.where((s) => s.status == _selectedStatus).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final idToStudent = {for (final s in students) s.id: s};
      filtered = filtered.where((s) {
        final student = idToStudent[s.studentId];
        final inStudent = student != null &&
            (student.fullName.toLowerCase().contains(q) ||
                student.email.toLowerCase().contains(q) ||
                (student.seatNumber?.toLowerCase().contains(q) ?? false));
        return s.planName.toLowerCase().contains(q) || inStudent;
      }).toList();
    }
    
    return filtered;
  }

  Widget _buildListView(
    List<Subscription> subscriptions,
    List<Student> students,
  ) {
    final idToStudent = {for (final s in students) s.id: s};
    // final isTablet = ResponsiveUtils.isTablet(context); // unused
    final padding = ResponsiveUtils.getResponsivePadding(context);
    if (ResponsiveUtils.isMobile(context)) {
      return SliverPadding(
        padding: padding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
        final subscription = subscriptions[index];
            final studentName = idToStudent[subscription.studentId]?.fullName;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SubscriptionCard(
            subscription: subscription,
                studentName: studentName,
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
      // Responsive grid: use fewer columns on narrower widths
      final screenWidth = MediaQuery.of(context).size.width;
      final crossAxisCount = screenWidth < 1200 ? 2 : 3;
      // Make tiles taller to prevent vertical overflow in dense layouts
      // lower aspect ratio => more height
      double aspect;
      if (screenWidth < 900) {
        aspect = 0.82; // very tall on narrow tablet widths
      } else if (screenWidth < 1200) {
        aspect = 1.0;  // tall on medium widths
      } else {
        aspect = 1.22; // balanced on wide desktops
      }
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final subscription = subscriptions[index];
            final studentName = idToStudent[subscription.studentId]?.fullName;
            return SubscriptionCard(
              subscription: subscription,
              studentName: studentName,
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
            childAspectRatio: aspect,
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
              textAlign: TextAlign.center,
          ),
        ],
      ),
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    // Define sheet state outside the builder so they persist across rebuilds
    final formKey = GlobalKey<FormState>();
    final studentIdCtrl = TextEditingController();
    final planCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime? start = DateTime.now();
    DateTime? end = DateTime.now().add(const Duration(days: 30));
    var status = SubscriptionStatus.active;
    // free-form plan name; no fixed selection
    Student? selectedStudent;

    showAppBottomSheet<void>(
      context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
          Future<void> pickDate({required bool isStart}) async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: ctx,
                initialDate: isStart ? (start ?? now) : (end ?? now),
              firstDate: DateTime(now.year - 10),
              lastDate: DateTime(now.year + 10),
              );
              if (date != null) {
                setSheetState(() {
                  if (isStart) {
                    start = date;
                  } else {
                    end = date;
                  }
                });
              }
            }

            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add Subscription',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TypeaheadStudentField(
                      initial: selectedStudent,
                      onSelected: (s) {
                        setSheetState(() {
                          selectedStudent = s;
                        });
                        if (s != null) {
                          studentIdCtrl.text = s.id;
                          debugPrint(
                            'Selected student: ${s.fullName} (ID: ${s.id})',
                          );
                        } else {
                          studentIdCtrl.clear();
                          debugPrint('Student selection cleared');
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: studentIdCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Selected Student ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Please select a student' : null,
                    ),
                    // Debug info - show selected student
                    if (selectedStudent != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: ${selectedStudent?.fullName ?? 'No student selected'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Plan name',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: planCtrl,
                      decoration: InputDecoration(
                        labelText: 'e.g. Monthly, Quarterly, Yearly, or custom',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Plan name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed < 0) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Duration',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () => pickDate(isStart: true),
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                start == null
                                    ? 'Start date'
                                    : '${start!.day}/${start!.month}/${start!.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () => pickDate(isStart: false),
                              icon: const Icon(Icons.event),
                              label: Text(
                                end == null
                                    ? 'End date'
                                    : '${end!.day}/${end!.month}/${end!.year}',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Status',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: ButtonTheme(
                          alignedDropdown: true,
                          child: DropdownButton<SubscriptionStatus>(
                            value: status,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: theme.colorScheme.onSurface,
                            ),
                            items: SubscriptionStatus.values
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(_getStatusDisplayName(s)),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setSheetState(() {
                              status = v ?? SubscriptionStatus.active;
                            }),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (start != null && end != null && end!.isBefore(start!))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Start date cannot be after End date.\nTips: Set Start earlier than or equal to End.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (start != null && end != null && !end!.isBefore(start!))
                            ? () => _createSubscription(
                          formKey: formKey,
                          studentIdCtrl: studentIdCtrl,
                           planCtrl: planCtrl,
                          amountCtrl: amountCtrl,
                          start: start,
                          end: end,
                          status: status,
                          )
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Create Subscription'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createSubscription({
    required GlobalKey<FormState> formKey,
    required TextEditingController studentIdCtrl,
    required TextEditingController planCtrl,
    required TextEditingController amountCtrl,
    required DateTime? start,
    required DateTime? end,
    required SubscriptionStatus status,
  }) async {
    if (!formKey.currentState!.validate()) return;
    if (start == null || end == null) return;

    final studentId = studentIdCtrl.text.trim();
    final planName = planCtrl.text.trim();
    final amountText = amountCtrl.text.trim();

    // Validation
    if (studentId.isEmpty) {
      if (context.mounted) {
        CustomNotification.show(
          context,
          message: 'Please select a student',
          type: NotificationType.warning,
        );
      }
      return;
    }

    if (planName.isEmpty) {
      if (context.mounted) {
        CustomNotification.show(
          context,
          message: 'Please select a plan',
          type: NotificationType.warning,
        );
      }
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        CustomNotification.show(
          context,
          message: 'Please enter a valid amount',
          type: NotificationType.warning,
        );
      }
      return;
    }

    debugPrint(
      'Creating subscription: studentId=$studentId, plan=$planName, amount=$amount',
    );

    try {
      await ref
          .read(subscriptionsNotifierProvider.notifier)
          .createSubscription(
            studentId: studentId,
            planName: planName,
            startDate: start,
            endDate: end,
            amount: amount,
            status: status,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      CustomNotification.show(
        context,
        message: 'Subscription created successfully',
        type: NotificationType.success,
      );
    } catch (e, st) {
      TelemetryService.instance.captureException(
        e,
        st,
        feature: 'create_subscription',
        context: {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
          'amount': amount,
          'student_id': studentId,
          'plan': planName,
        },
      );
      if (!mounted) return;
      // Map to friendly message without technicals
      final msg = ErrorMapper.friendly(e);
      setState(() {
        _overlapBannerMessage = ErrorMapper.isOverlap(e)
            ? 'This period overlaps an existing subscription.'
            : _overlapBannerMessage;
      });
      CustomNotification.show(
        context,
        message: msg,
        type: NotificationType.error,
      );
    }
  }

  void _showEditSubscriptionDialog(Subscription subscription) {
    showAppBottomSheet<void>(
      context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        final planCtrl = TextEditingController(text: subscription.planName);
        final amountCtrl = TextEditingController(
          text: subscription.amount.toString(),
        );
        var start = subscription.startDate;
        var end = subscription.endDate;
        var status = subscription.status;
        final theme = Theme.of(context);

        Future<void> pickDate({required bool isStart}) async {
          final now = DateTime.now();
          final date = await showDatePicker(
            context: context,
            initialDate: isStart ? start : end,
            firstDate: DateTime(now.year - 10),
            lastDate: DateTime(now.year + 10),
          );
          if (date != null) {
            if (isStart) {
              start = date;
            } else {
              end = date;
            }
            (context as Element).markNeedsBuild();
          }
        }

        return SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
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
                // top-of-sheet warning banner when overlap detected (hydrated on catch)
                if (_overlapBannerMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _overlapBannerMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // focus Duration section by ensuring it is visible
                            (context as Element).markNeedsBuild();
                          },
                          child: const Text('Review dates'),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Edit Subscription',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (end.isBefore(start))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Start date cannot be after End date.\nTips: Start must be earlier than or equal to End.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Plan name',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: planCtrl,
                  decoration: InputDecoration(
                    labelText: 'e.g. Monthly, Yearly, or custom',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Plan name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final parsed = double.tryParse(v);
                    if (parsed == null || parsed < 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Duration',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: () => pickDate(isStart: true),
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            '${start.day}/${start.month}/${start.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: () => pickDate(isStart: false),
                          icon: const Icon(Icons.event),
                          label: Text('${end.day}/${end.month}/${end.year}'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Status',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<SubscriptionStatus>(
                        value: status,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: theme.colorScheme.onSurface,
                        ),
                        items: SubscriptionStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(_getStatusDisplayName(s)),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => status = v ?? status,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (!end.isBefore(start))
                        ? () => _saveEdit(
                      formKey: formKey,
                      original: subscription,
                      planCtrl: planCtrl,
                      amountCtrl: amountCtrl,
                      start: start,
                      end: end,
                      status: status,
                    )
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveEdit({
    required GlobalKey<FormState> formKey,
    required Subscription original,
    required TextEditingController planCtrl,
    required TextEditingController amountCtrl,
    required DateTime start,
    required DateTime end,
    required SubscriptionStatus status,
  }) async {
    if (!formKey.currentState!.validate()) return;
    if (end.isBefore(start)) {
      if (context.mounted) {
        CustomNotification.show(
          context,
          message: 'End date must be after start date',
          type: NotificationType.warning,
        );
      }
      return;
    }
    try {
      try {
        await ref
            .read(subscriptionsNotifierProvider.notifier)
            .updateSubscription(
              original.copyWith(
                planName: planCtrl.text.trim(),
                amount: double.parse(amountCtrl.text.trim()),
                startDate: start,
                endDate: end,
                status: status,
              ),
            );
      } catch (e, st) {
        TelemetryService.instance.captureException(
          e,
          st,
          feature: 'edit_subscription',
          context: {
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
            'amount': amountCtrl.text.trim(),
            'subscription_id': original.id,
          },
        );
        if (!context.mounted) return;
        final msg = ErrorMapper.friendly(e);
        setState(() {
          _overlapBannerMessage = ErrorMapper.isOverlap(e)
              ? 'This period overlaps an existing subscription.'
              : _overlapBannerMessage;
        });
        if (mounted) {
          CustomNotification.show(
            context,
            message: msg,
            type: NotificationType.error,
          );
        }
        // Optional: allow admin to proceed anyway for backdating corrections
        if (ErrorMapper.isOverlap(e) && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirm date change'),
              content: const Text(
                'The selected dates overlap an existing period. If you intend to correct past records, you can proceed. Otherwise, adjust dates to avoid overlap.',
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
          );
          if (proceed ?? false) {
            await ref
                .read(subscriptionsNotifierProvider.notifier)
                .updateSubscription(
                  original.copyWith(
                    planName: planCtrl.text.trim(),
                    amount: double.parse(amountCtrl.text.trim()),
                    startDate: start,
                    endDate: end,
                    status: status,
                  ),
                  allowOverlap: true,
                );
          }
        }
      }
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        CustomNotification.show(
          context,
          message: 'Error: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _cancelSubscription(Subscription subscription) async {
    await showAppBottomSheet<void>(
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancel Subscription',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to cancel this subscription for ${subscription.planName}?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: () async {
                      // theme is available via context if needed
                      if (mounted) Navigator.of(context).pop();
                      try {
                        await ref
                            .read(subscriptionsNotifierProvider.notifier)
                            .cancelSubscription(subscription.id);
                        if (mounted) {
                          CustomNotification.show(
                            context,
                            message: 'Subscription cancelled successfully',
                            type: NotificationType.success,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomNotification.show(
                            context,
                            message: 'Error cancelling subscription: $e',
                            type: NotificationType.error,
                          );
                        }
                      }
                    },
                    text: 'Cancel Subscription',
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _renewSubscription(Subscription subscription) async {
    // final currentTheme = Theme.of(context); // unused
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: subscription.endDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;

    // Ask admin for renewal amount instead of forcing 0
    final amountCtrl = TextEditingController(text: subscription.amount.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
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
                    type: NotificationType.warning,
                  );
                  return;
                }
                Navigator.of(ctx).pop(v);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (amount == null) return;

    try {
      try {
        await ref
            .read(subscriptionsNotifierProvider.notifier)
            .renewSubscription(subscription.id, picked, amount);
      } catch (e, st) {
        TelemetryService.instance.captureException(
          e,
          st,
          feature: 'renew_subscription',
          context: {
            'current_end': subscription.endDate.toIso8601String(),
            'picked': picked.toIso8601String(),
            'subscription_id': subscription.id,
          },
        );
        if (!context.mounted) return;
        final msg = ErrorMapper.friendly(e);
        setState(() {
          _overlapBannerMessage = ErrorMapper.isOverlap(e)
              ? 'This renewal overlaps a previous period.'
              : _overlapBannerMessage;
        });
        if (mounted) {
          CustomNotification.show(
            context,
            message: msg,
            type: NotificationType.error,
          );
        }
        if (ErrorMapper.isOverlap(e) && mounted) {
          final proceed = await showDialog<bool>(
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
          );
          if (proceed ?? false) {
            await ref
                .read(subscriptionsNotifierProvider.notifier)
                .renewSubscription(subscription.id, picked, amount, allowOverlap: true);
          }
        }
      }
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Subscription renewed successfully',
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
