import 'package:flutter/material.dart';
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
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
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

  String? _overlapBannerMessage;

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
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() => _isLoadingPage = true);
    try {
      final next = await ref
          .read(pagedSubscriptionsProvider((offset: _offset, limit: _pageSize)).future);
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
          SliverToBoxAdapter(
            child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context).copyWith(top: 8),
              child: _buildModernHeader(theme),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context).copyWith(top: 16),
                  child: SubscriptionFilters(
                    selectedStatus: _selectedStatus,
                    searchQuery: _searchQuery,
                    onStatusChanged: (status) {
                    setState(() => _selectedStatus = status);
                    },
                    onSearchChanged: (query) {
                    setState(() => _searchQuery = query);
                    },
              ),
                  ),
                ),
            SliverToBoxAdapter(child: SizedBox(height: 8)),
          subscriptionsAsync.when(
            data: (subscriptions) => studentsAsync.when(
              data: (students) {
                  final source = _paged.isEmpty ? subscriptions : _paged;
                  final filtered = _filterSubscriptions(source, students);
                  if (filtered.isEmpty) {
                  return SliverToBoxAdapter(child: _buildEmptyState(theme));
                      }
                final idToStudent = {for (final s in students) s.id: s};
                      return _isTimelineView
                    ? SliverToBoxAdapter(
                        child: SubscriptionTimeline(
                            subscriptions: filtered,
                            studentNamesById: idToStudent.map((k, v) => MapEntry(k, v.fullName)),
                          ),
                        )
                      : _buildListView(filtered, students);
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
              error: (error, _) => SliverToBoxAdapter(
              child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                      Text('Error loading subscriptions', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                      PrimaryButton(text: 'Retry', onPressed: () => ref.invalidate(subscriptionsProvider)),
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
              Text('Subscriptions',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  )),
              Text('Manage subscription plans and payments',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
            IconButton(
          onPressed: () => setState(() => _isTimelineView = !_isTimelineView),
              icon: Icon(
            _isTimelineView ? Icons.view_list_outlined : Icons.timeline_outlined,
                color: theme.colorScheme.onSurface,
              ),
              tooltip: _isTimelineView ? 'List View' : 'Timeline View',
        ),
      ],
    );
  }

  List<Subscription> _filterSubscriptions(List<Subscription> subscriptions, List<Student> students) {
    var filtered = subscriptions;
    if (_selectedStatus != null) {
      filtered = filtered.where((s) => s.status == _selectedStatus).toList();
    }
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

  Widget _buildListView(List<Subscription> subscriptions, List<Student> students) {
    final idToStudent = {for (final s in students) s.id: s};
    final padding = ResponsiveUtils.getResponsivePadding(context);
    if (ResponsiveUtils.isMobile(context)) {
      return SliverPadding(
        padding: padding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
        final subscription = subscriptions[index];
              final student = idToStudent[subscription.studentId];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SubscriptionCard(
            subscription: subscription,
                  studentName: student?.fullName,
                  studentAvatarPath: student?.profileImagePath,
                  studentInitials: student?.initials,
                  onTap: () => context.go('/students/details/${subscription.studentId}'),
            onEdit: () => _showEditSubscriptionDialog(subscription),
            onCancel: () => _cancelSubscription(subscription),
            onRenew: () => _renewSubscription(subscription),
            onDelete: () => _confirmDelete(subscription),
          ),
        );
            },
            childCount: subscriptions.length,
          ),
        ),
      );
    } else {
      final media = MediaQuery.of(context);
      final screenWidth = media.size.width;
      final isLandscape = media.orientation == Orientation.landscape;
      final double minTileWidth = isLandscape ? 360 : 320;
      int crossAxisCount = (screenWidth / minTileWidth).floor();
      if (crossAxisCount < 2) crossAxisCount = 2;
      if (crossAxisCount > 6) crossAxisCount = 6;
      final double aspect = isLandscape ? 1.2 : 1.5;
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
            final subscription = subscriptions[index];
              final student = idToStudent[subscription.studentId];
            return RepaintBoundary(
              child: SubscriptionCard(
                subscription: subscription,
                studentName: student?.fullName,
                studentAvatarPath: student?.profileImagePath,
                studentInitials: student?.initials,
                onTap: () => context.go('/students/details/${subscription.studentId}'),
              onEdit: () => _showEditSubscriptionDialog(subscription),
              onCancel: () => _cancelSubscription(subscription),
              onRenew: () => _renewSubscription(subscription),
              onDelete: () => _confirmDelete(subscription),
              )
            );
            
            },
            childCount: subscriptions.length,
          ),
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
              child: Icon(Icons.card_membership_outlined, size: 64, color: theme.colorScheme.primary),
          ),
            const SizedBox(height: 24),
            Text('No subscriptions found',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Create your first subscription to get started',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
          ),
        ],
      ),
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final studentIdCtrl = TextEditingController();
    final planCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime? start;
    DateTime? end;
    var status = SubscriptionStatus.active;
    Student? selectedStudent;

    showAppBottomSheet<void>(
      context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
          Future<void> pickDate({required bool isStart}) async {
              final date = await showDatePicker(
                context: ctx,
                initialDate: isStart
                    ? (start ?? DateTime.now())
                    : (end ?? (start != null ? start!.add(const Duration(days: 30)) : DateTime.now())),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Add Subscription',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TypeaheadStudentField(
                      initial: selectedStudent,
                      onSelected: (s) {
                        setSheetState(() => selectedStudent = s);
                        if (s != null) {
                          studentIdCtrl.text = s.id;
                        } else {
                          studentIdCtrl.clear();
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
                    const SizedBox(height: 16),
                    Text('Plan name',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        )),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: planCtrl,
                      decoration: InputDecoration(
                        labelText: 'e.g. Monthly, Quarterly, Yearly, or custom',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Plan name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed < 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Duration',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        )),
                    const SizedBox(height: 8),
                    Row(children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            ),
                            child: TextButton.icon(
                              onPressed: () => pickDate(isStart: true),
                              icon: const Icon(Icons.date_range),
                            label: Text(start == null
                                    ? 'Start date'
                                : '${start!.day}/${start!.month}/${start!.year}'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            ),
                            child: TextButton.icon(
                              onPressed: () => pickDate(isStart: false),
                              icon: const Icon(Icons.event),
                            label: Text(end == null
                                    ? 'End date'
                                : '${end!.day}/${end!.month}/${end!.year}'),
                              ),
                            ),
                          ),
                    ]),
                    const SizedBox(height: 16),
                    Text('Status',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        )),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: ButtonTheme(
                          alignedDropdown: true,
                          child: DropdownButton<SubscriptionStatus>(
                            value: status,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down_rounded, color: theme.colorScheme.onSurface),
                            items: SubscriptionStatus.values
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(_getStatusDisplayName(s)),
                                    ),
                                    ))
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    if (studentId.isEmpty) {
      if (context.mounted) {
        CustomNotification.show(context, message: 'Please select a student', type: NotificationType.warning);
      }
      return;
    }
    if (planName.isEmpty) {
      if (context.mounted) {
        CustomNotification.show(context, message: 'Please select a plan', type: NotificationType.warning);
      }
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        CustomNotification.show(context, message: 'Please enter a valid amount', type: NotificationType.warning);
      }
      return;
    }

    try {
      await ref.read(subscriptionsNotifierProvider.notifier).createSubscription(
            studentId: studentId,
            planName: planName,
            startDate: start,
            endDate: end,
            amount: amount,
            status: status,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      await _onRefresh();
      CustomNotification.show(context, message: 'Subscription created successfully', type: NotificationType.success);
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
      final msg = ErrorMapper.friendly(e);
      setState(() {
        _overlapBannerMessage = ErrorMapper.isOverlap(e)
            ? 'This period overlaps an existing subscription.'
            : _overlapBannerMessage;
      });
      CustomNotification.show(context, message: msg, type: NotificationType.error);
    }
  }

  void _showEditSubscriptionDialog(Subscription subscription) {
    showAppBottomSheet<void>(
      context,
      builder: (context) {
        return _EditSubscriptionSheet(subscription: subscription, onSaved: _onRefresh);
      },
    );
  }

  Future<void> _confirmDelete(Subscription s) async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
        title: const Text('Delete subscription?'),
        content: Text('This will permanently delete the "${s.planName}" subscription.'),
              actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
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
        await _onRefresh();
        if (mounted) {
          CustomNotification.show(context, message: 'Subscription deleted', type: NotificationType.success);
        }
    } catch (e) {
        if (mounted) {
          CustomNotification.show(context, message: 'Error deleting subscription: $e', type: NotificationType.error);
        }
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
                  Text('Cancel Subscription', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Are you sure you want to cancel this subscription for ${subscription.planName}?', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: () async {
                      if (mounted) Navigator.of(context).pop();
                      try {
                        await ref.read(subscriptionsNotifierProvider.notifier).cancelSubscription(subscription.id);
                        await _onRefresh();
                        if (mounted) {
                          CustomNotification.show(context, message: 'Subscription cancelled successfully', type: NotificationType.success);
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomNotification.show(context, message: 'Error cancelling subscription: $e', type: NotificationType.error);
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: subscription.endDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;

    final amountCtrl = TextEditingController(text: subscription.amount.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Renew Subscription'),
          content: TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Renewal amount', prefixIcon: Icon(Icons.currency_rupee)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(amountCtrl.text.trim());
                if (v == null || v < 0) {
                  CustomNotification.show(ctx, message: 'Enter a valid amount', type: NotificationType.warning);
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
        await ref.read(subscriptionsNotifierProvider.notifier).renewSubscription(subscription.id, picked, amount);
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
          CustomNotification.show(context, message: msg, type: NotificationType.error);
        }
        if (ErrorMapper.isOverlap(e) && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirm renewal change'),
              content: const Text('The new end date overlaps a previous period. Proceed only if you are backdating intentionally.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Adjust dates')),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Proceed anyway')),
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
        await _onRefresh();
        CustomNotification.show(context, message: 'Subscription renewed successfully', type: NotificationType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(context, message: 'Error: $e', type: NotificationType.error);
      }
    }
  }
}

class _EditSubscriptionSheet extends ConsumerStatefulWidget {
  const _EditSubscriptionSheet({required this.subscription, required this.onSaved});
  final Subscription subscription;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_EditSubscriptionSheet> createState() => _EditSubscriptionSheetState();
}

class _EditSubscriptionSheetState extends ConsumerState<_EditSubscriptionSheet> {
  late final TextEditingController _planCtrl;
  late final TextEditingController _amountCtrl;
  late SubscriptionStatus _status;
  late DateTime _start;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    _planCtrl = TextEditingController(text: s.planName);
    _amountCtrl = TextEditingController(text: s.amount.toString());
    _status = s.status;
    _start = s.startDate;
  }

  @override
  void dispose() {
    _planCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Edit Subscription',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          
          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan name
                    TextFormField(
                      controller: _planCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Plan Name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Amount
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed < 0) return 'Invalid amount';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    
                    // Status
                    DropdownButtonFormField<SubscriptionStatus>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: SubscriptionStatus.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(_getStatusDisplayName(s)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),

                    const SizedBox(height: 16),
                    
                    // Start date
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                        hintText: '${_start.day}/${_start.month}/${_start.year}',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _start,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: 'Select new start date',
                        );
                        if (picked != null) {
                          final newStart = DateTime(picked.year, picked.month, picked.day);
                          if (!widget.subscription.endDate.isAfter(newStart)) {
                            if (mounted) {
                              CustomNotification.show(
                                context,
                                message: 'Start must be before end date',
                                type: NotificationType.warning,
                              );
                            }
                            return;
                          }
                          setState(() => _start = newStart);
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                    
                    // End date (read-only)
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'End Date (Read-only)',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.lock),
                        hintText: '${widget.subscription.endDate.day}/${widget.subscription.endDate.month}/${widget.subscription.endDate.year}',
                        helperText: 'Use Renew to extend',
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplayName(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.pending:
        return 'Pending';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Additional validation
    final planName = _planCtrl.text.trim();
    final amountText = _amountCtrl.text.trim();
    
    if (planName.isEmpty) {
      CustomNotification.show(
        context,
        message: 'Plan name cannot be empty',
        type: NotificationType.warning,
      );
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      CustomNotification.show(
        context,
        message: 'Amount must be a valid positive number',
        type: NotificationType.warning,
      );
      return;
    }
    
    if (_start.isAfter(widget.subscription.endDate)) {
      CustomNotification.show(
        context,
        message: 'Start date cannot be after the current end date',
        type: NotificationType.warning,
      );
      return;
    }

    try {
      final notifier = ref.read(subscriptionsNotifierProvider.notifier);
      
      // Create updated subscription with validation
      final updatedSubscription = widget.subscription.copyWith(
        planName: planName,
        amount: amount,
        startDate: _start,
        status: _status,
        updatedAt: DateTime.now(), // Ensure updated timestamp
      );
      
      // Update in database with activity logging
      await notifier.updateSubscription(updatedSubscription);
      
      // Force immediate refresh of all subscription-related providers
      ref.invalidate(subscriptionsProvider);
      ref.invalidate(subscriptionsByStudentProvider(widget.subscription.studentId));
      ref.invalidate(subscriptionByIdProvider(widget.subscription.id));
      
      // Refresh UI immediately
      await widget.onSaved();
      
      if (context.mounted) {
        Navigator.of(context).pop();
        CustomNotification.show(
          context,
          message: 'Subscription "${planName}" updated successfully',
          type: NotificationType.success,
        );
      }
    } catch (e, stackTrace) {
      // Log error for debugging
      TelemetryService.instance.captureException(
        e,
        stackTrace,
        feature: 'edit_subscription',
        context: {
          'subscription_id': widget.subscription.id,
          'plan_name': planName,
          'amount': amount,
          'start_date': _start.toIso8601String(),
          'status': _status.name,
        },
      );
      
      if (context.mounted) {
        final friendlyMessage = ErrorMapper.friendly(e);
        CustomNotification.show(
          context,
          message: 'Failed to update subscription: $friendlyMessage',
          type: NotificationType.error,
        );
      }
    }
  }
}


