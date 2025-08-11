import 'package:flutter/material.dart';
import 'package:library_registration_app/core/utils/telemetry_service.dart';
import 'package:library_registration_app/core/utils/error_mapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_notifier.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';

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
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEdit(context, ref, sub),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showRenew(context, ref, sub.id, sub.endDate),
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Renew'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showCancel(context, ref, sub.id, sub.planName),
                      icon: const Icon(Icons.cancel_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                      label: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
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
        final formKey = GlobalKey<FormState>();
        final planCtrl = TextEditingController(text: sub.planName);
        final amountCtrl = TextEditingController(text: sub.amount.toString());
        var start = sub.startDate;
        var end = sub.endDate;
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
                            context: ctx,
                            initialDate: start,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            start = picked;
                            (ctx as Element).markNeedsBuild();
                          }
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          '${start.day}/${start.month}/${start.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: end,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            end = picked;
                            (ctx as Element).markNeedsBuild();
                          }
                        },
                        icon: const Icon(Icons.event),
                        label: Text('${end.day}/${end.month}/${end.year}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (end.isBefore(start)) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('End date must be after start date'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                        return;
                      }
                      await ref
                          .read(subscriptionsNotifierProvider.notifier)
                          .updateSubscription(
                            sub.copyWith(
                              planName: planCtrl.text.trim(),
                              amount: double.parse(amountCtrl.text.trim()),
                              startDate: start,
                              endDate: end,
                            ),
                          );
                      if (context.mounted) Navigator.of(ctx).pop();
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
    try {
      await ref
          .read(subscriptionsNotifierProvider.notifier)
          .renewSubscription(id, picked, 0);
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
              .renewSubscription(id, picked, 0, allowOverlap: true);
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
