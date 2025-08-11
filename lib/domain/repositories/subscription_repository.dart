import 'package:library_registration_app/domain/entities/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getAllSubscriptions();
  Future<List<Subscription>> getActiveSubscriptions();
  Future<List<Subscription>> getExpiredSubscriptions();
  Future<List<Subscription>> getSubscriptionsByStatus(
    SubscriptionStatus status,
  );
  Future<List<Subscription>> getSubscriptionsByStudent(String studentId);
  Future<Subscription?> getSubscriptionById(String id);
  Future<Subscription?> getActiveSubscriptionByStudent(String studentId);
  Future<List<Subscription>> getExpiringSubscriptions(int days);
  Future<List<Subscription>> getSubscriptionsPaginated(int offset, int limit);
  Future<int> getSubscriptionsCount();
  Future<int> getActiveSubscriptionsCount();
  Future<double> getTotalRevenue();
  Future<double> getRevenueByDateRange(DateTime startDate, DateTime endDate);

  Future<String> createSubscription(Subscription subscription, {bool allowOverlap = false});
  Future<void> updateSubscription(Subscription subscription, {bool allowOverlap = false});
  Future<void> cancelSubscription(String id);
  Future<void> renewSubscription(String id, DateTime newEndDate, double amount, {bool allowOverlap = false});
  Future<void> deleteSubscription(String id);

  Stream<List<Subscription>> watchAllSubscriptions();
  Stream<List<Subscription>> watchActiveSubscriptions();
  Stream<List<Subscription>> watchSubscriptionsByStudent(String studentId);
  Stream<Subscription?> watchSubscriptionById(String id);
}
