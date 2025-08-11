import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
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
import 'package:library_registration_app/core/utils/telemetry_service.dart';
import 'package:library_registration_app/core/utils/error_mapper.dart';

const kPlans = <String, double>{
  'Monthly': 1000,
  'Quarterly': 2500,
  'Yearly': 7500,
};

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final studentsAsync = ref.watch(allStudentsProvider);
    
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
                
                // Content
          SliverToBoxAdapter(
            child: SizedBox(
              height: ResponsiveUtils.getResponsivePadding(context).top,
            ),
          ),

          subscriptionsAsync.when(
            data: (subscriptions) => studentsAsync.when(
              data: (students) {
                final filteredSubscriptions = _filterSubscriptions(
                  subscriptions,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubscriptionDialog(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add_outlined),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
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
    if (confirmed == true) {
      try {
        await ref.read(subscriptionsNotifierProvider.notifier).deleteSubscription(s.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting subscription: $e')),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            IconButton(
              onPressed: () =>
                  ref.read(subscriptionsNotifierProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
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
        final inStudent = student == null
            ? false
            : (student.fullName.toLowerCase().contains(q) ||
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
                    context.go('/subscriptions/details/${subscription.id}'),
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
                  context.go('/subscriptions/details/${subscription.id}'),
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
    String? selectedPlan = 'Monthly';
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
                      'Plan',
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
                          child: DropdownButton<String>(
                            value: selectedPlan,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: theme.colorScheme.onSurface,
                            ),
                            items: kPlans.keys
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(p),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setSheetState(() {
                                selectedPlan = v;
                                amountCtrl.text = kPlans[v]!.toStringAsFixed(2);
                                planCtrl.text = v;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountCtrl
                        ..text = (kPlans[selectedPlan] ?? 0).toStringAsFixed(2),
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
                          planCtrl: planCtrl..text = selectedPlan!,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a student'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (planName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a plan'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
            content: Text('Please enter a valid amount'),
            backgroundColor: Colors.orange,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription created successfully'),
          backgroundColor: Colors.green,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          action: SnackBarAction(
            label: 'Review dates',
            onPressed: () {},
          ),
        ),
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
        String? selectedPlan = kPlans.keys.contains(subscription.planName)
            ? subscription.planName
            : 'Monthly';
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
                  'Plan',
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
                      child: DropdownButton<String>(
                        value: selectedPlan,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: theme.colorScheme.onSurface,
                        ),
                        items: kPlans.keys
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(p),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          selectedPlan = v;
                          amountCtrl.text = kPlans[v]!.toStringAsFixed(2);
                          planCtrl.text = v!;
                        },
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
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
                      planCtrl: planCtrl..text = selectedPlan!,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date must be after start date'),
            backgroundColor: Colors.orange,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: SnackBarAction(
              label: 'Review dates',
              onPressed: () {
                // no-op; fields are visible in sheet
              },
            ),
          ),
        );
        // Optional: allow admin to proceed anyway for backdating corrections
        if (ErrorMapper.isOverlap(e)) {
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
          if (proceed == true) {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cancelSubscription(Subscription subscription) async {
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
                      if (mounted) Navigator.of(context).pop();
                      try {
                        await ref
                            .read(subscriptionsNotifierProvider.notifier)
            .cancelSubscription(subscription.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                              content: Text(
                                'Subscription cancelled successfully',
                              ),
                              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                              content: Text(
                                'Error cancelling subscription: $e',
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
            ),
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: subscription.endDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    try {
      try {
        await ref
            .read(subscriptionsNotifierProvider.notifier)
            .renewSubscription(subscription.id, picked, 0);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: SnackBarAction(
              label: 'Review dates',
              onPressed: () {},
            ),
          ),
        );
        if (ErrorMapper.isOverlap(e)) {
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
          if (proceed == true) {
            await ref
                .read(subscriptionsNotifierProvider.notifier)
                .renewSubscription(subscription.id, picked, 0, allowOverlap: true);
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription renewed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
  }
}
