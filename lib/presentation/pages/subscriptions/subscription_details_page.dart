import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/core/utils/error_mapper.dart';
import 'package:library_registration_app/core/utils/telemetry_service.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_notifier.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';

class SubscriptionDetailsPage extends ConsumerWidget {
  const SubscriptionDetailsPage({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subAsync = ref.watch(subscriptionByIdProvider(id));
    final dateFmt = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        toolbarHeight: 56,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  _showEdit(context, ref, (ref.read(subscriptionByIdProvider(id)).value)!);
                  break;
                case 'renew':
                  {
                    final s = ref.read(subscriptionByIdProvider(id)).value;
                    if (s != null) {
                      await _showRenew(context, ref, s.id, s.endDate);
                    }
                    break;
                  }
                case 'cancel':
                  {
                    final s = ref.read(subscriptionByIdProvider(id)).value;
                    if (s != null) {
                      _showCancel(context, ref, s.id, s.planName);
                    }
                    break;
                  }
                case 'delete':
                  {
                    final s = ref.read(subscriptionByIdProvider(id)).value;
                    if (s != null) {
                      await ref
                          .read(subscriptionsNotifierProvider.notifier)
                          .deleteSubscription(s.id);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                    break;
                  }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'renew',
                child: ListTile(
                  leading: Icon(Icons.refresh_outlined),
                  title: Text('Renew'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'cancel',
                child: ListTile(
                  leading: Icon(Icons.cancel_outlined),
                  title: Text('Cancel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: subAsync.when(
        data: (Subscription? sub) {
          if (sub == null) {
            return const Center(child: Text('Not found'));
          }
          final studentAsync = ref.watch(studentByIdProvider(sub.studentId));
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.planName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${dateFmt.format(sub.startDate)} – ${dateFmt.format(sub.endDate)}',
                      ),
                      const SizedBox(height: 8),
                      Text('Amount: ${sub.amount.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      Text('Status: ${sub.status.name}'),
                      const Divider(height: 32),
                      studentAsync.when(
                        data: (s) => s == null
                            ? const SizedBox()
                            : ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(s.fullName),
                                subtitle: Text(s.email),
                              ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom bar removed; actions moved to AppBar 3-dot menu.
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, Subscription sub) {
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        // Keep controllers outside builder to avoid keyboard focus flicker
        final formKey = GlobalKey<FormState>();
        final planCtrl = TextEditingController(text: sub.planName);
        final amountCtrl = TextEditingController(text: sub.amount.toString());
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // Dates are view-only in Edit per policy
            return SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Subscription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: planCtrl,
                  decoration: const InputDecoration(labelText: 'Plan Name'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount'),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: sheetCtx,
                            initialDate: sub.startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            helpText: 'Select new start date',
                          );
                          if (picked != null) {
                            final newStart = DateTime(picked.year, picked.month, picked.day);
                            if (!sub.endDate.isAfter(newStart)) {
                              CustomNotification.show(
                                sheetCtx,
                                message: 'Start must be before current end date (${sub.endDate.day}/${sub.endDate.month}/${sub.endDate.year})',
                                type: NotificationType.warning,
                              );
                              return;
                            }
                            await ref
                                .read(subscriptionsNotifierProvider.notifier)
                                .updateSubscription(
                                  sub.copyWith(startDate: newStart),
                                );
                            // Invalidate specific providers for immediate UI update
                            ref.invalidate(subscriptionsProvider);
                            ref.invalidate(subscriptionsByStudentProvider(sub.studentId));
                            ref.invalidate(subscriptionByIdProvider(sub.id));
                            if (context.mounted) {
                              Navigator.of(sheetCtx).pop();
                              CustomNotification.show(context, message: 'Start date updated', type: NotificationType.success);
                            }
                          }
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          '${sub.startDate.day}/${sub.startDate.month}/${sub.startDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.event),
                        label: Text('${sub.endDate.day}/${sub.endDate.month}/${sub.endDate.year}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'End date is managed by Renew. Edit lets you change only the start date.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await ref
                          .read(subscriptionsNotifierProvider.notifier)
                          .updateSubscription(
                            sub.copyWith(
                              planName: planCtrl.text.trim(),
                              amount: double.parse(amountCtrl.text.trim()),
                            ),
                          );
                      // Ensure list tiles and counters reflect instantly
                      ref.read(subscriptionsNotifierProvider.notifier).refresh();
                      ref.invalidate(subscriptionByIdProvider(sub.id));
                      if (context.mounted) Navigator.of(sheetCtx).pop();
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRenew(
    BuildContext context,
    WidgetRef ref,
    String id,
    DateTime endDate,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    double? renewalAmount;
    try {
      // Prompt admin for renewal amount (free input)
      final amountCtrl = TextEditingController(text: '0.00');
      renewalAmount = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Renew Subscription'),
          content: TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Renewal amount',
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
        ),
      );
      if (renewalAmount == null) return;
      await ref
          .read(subscriptionsNotifierProvider.notifier)
          .renewSubscription(id, picked, renewalAmount);
    } catch (e, st) {
      TelemetryService.instance.captureException(
        e,
        st,
        feature: 'renew_subscription_details',
        context: {
          'subscription_id': id,
          'picked': picked.toIso8601String(),
        },
      );
      if (!context.mounted) return;
      final msg = ErrorMapper.friendly(e);
      CustomNotification.show(
        context,
        message: msg,
        type: NotificationType.error,
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
          if (proceed ?? false) {
            await ref
                .read(subscriptionsNotifierProvider.notifier)
                .renewSubscription(id, picked, renewalAmount!, allowOverlap: true);
          }
      }
    }
  }

  void _showCancel(
    BuildContext context,
    WidgetRef ref,
    String id,
    String planName,
  ) {
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cancel Subscription',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Are you sure you want to cancel $planName?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(subscriptionsNotifierProvider.notifier)
                        .cancelSubscription(id);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
