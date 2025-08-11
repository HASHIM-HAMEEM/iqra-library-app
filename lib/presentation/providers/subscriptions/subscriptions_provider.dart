import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';

// All subscriptions provider
final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.watchAllSubscriptions();
});

// Active subscriptions provider
final activeSubscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.watchActiveSubscriptions();
});

// Subscription by ID provider
final subscriptionByIdProvider = StreamProvider.family<Subscription?, String>((
  ref,
  id,
) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.watchSubscriptionById(id);
});

// Subscriptions by student provider
final subscriptionsByStudentProvider =
    StreamProvider.family<List<Subscription>, String>((ref, studentId) {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return repository.watchSubscriptionsByStudent(studentId);
    });

// Active subscription by student provider
final activeSubscriptionByStudentProvider =
    FutureProvider.family<Subscription?, String>((ref, studentId) {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return repository.getActiveSubscriptionByStudent(studentId);
    });

// Subscriptions count provider
final subscriptionsCountProvider = Provider<int>((ref) {
  final subscriptions = ref.watch(subscriptionsProvider);
  return subscriptions.when(
    data: (subscriptionsList) => subscriptionsList.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Active subscriptions count provider
final activeSubscriptionsCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.getActiveSubscriptionsCount();
});

// Total revenue provider
final totalRevenueProvider = FutureProvider<double>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.getTotalRevenue();
});

// Revenue by date range provider
final revenueByDateRangeProvider =
    FutureProvider.family<double, ({DateTime startDate, DateTime endDate})>((
      ref,
      params,
    ) {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return repository.getRevenueByDateRange(params.startDate, params.endDate);
    });

// Expired subscriptions provider
final expiredSubscriptionsProvider = FutureProvider<List<Subscription>>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.getExpiredSubscriptions();
});

// Expiring subscriptions provider
final expiringSubscriptionsProvider =
    FutureProvider.family<List<Subscription>, int>((ref, days) {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return repository.getExpiringSubscriptions(days);
    });

// Subscriptions by status provider
final subscriptionsByStatusProvider =
    FutureProvider.family<List<Subscription>, SubscriptionStatus>((
      ref,
      status,
    ) {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return repository.getSubscriptionsByStatus(status);
    });
