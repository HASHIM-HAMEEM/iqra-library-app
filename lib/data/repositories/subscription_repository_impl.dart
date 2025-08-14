// import 'package:library_registration_app/data/models/subscription_model.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/domain/repositories/subscription_repository.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._supabase);
  final SupabaseService _supabase;
  final Uuid _uuid = const Uuid();

  DateTime _normalizeUtcDay(DateTime dt) => DateTime.utc(dt.toUtc().year, dt.toUtc().month, dt.toUtc().day);

  bool _rangesOverlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    // inclusive overlap check on day granularity
    return !(aEnd.isBefore(bStart) || bEnd.isBefore(aStart));
  }

  Future<void> _ensureNoOverlapOrThrow({
    required String studentId,
    required DateTime startUtc,
    required DateTime endUtc,
    String? excludeId,
  }) async {
    final existing = await _supabase.getSubscriptionsByStudent(studentId);
    for (final sub in existing) {
      if (excludeId != null && sub.id == excludeId) continue;
      final s = _normalizeUtcDay(sub.startDate);
      final e = _normalizeUtcDay(sub.endDate);
      if (_rangesOverlap(startUtc, endUtc, s, e)) {
        final df = DateFormat('dd MMM yyyy');
        final range = '${df.format(s.toLocal())} to ${df.format(e.toLocal())}';
        throw Exception('This overlaps an existing subscription from $range.');
      }
    }
  }

  @override
  Future<List<Subscription>> getAllSubscriptions() async {
    return await _supabase.getAllSubscriptions();
  }

  @override
  Future<List<Subscription>> getActiveSubscriptions() async {
    return await _supabase.getActiveSubscriptions();
  }

  @override
  Future<List<Subscription>> getExpiredSubscriptions() async {
    return await _supabase.getExpiredSubscriptions();
  }

  @override
  Future<List<Subscription>> getSubscriptionsByStatus(
    SubscriptionStatus status,
  ) async {
    return await _supabase.getSubscriptionsByStatus(status.name);
  }

  @override
  Future<List<Subscription>> getSubscriptionsByStudent(String studentId) async {
    return await _supabase.getSubscriptionsByStudent(studentId);
  }

  @override
  Future<Subscription?> getSubscriptionById(String id) async {
    return await _supabase.getSubscriptionById(id);
  }

  @override
  Future<Subscription?> getActiveSubscriptionByStudent(String studentId) async {
    return await _supabase.getActiveSubscriptionByStudent(studentId);
  }

  @override
  Future<List<Subscription>> getExpiringSubscriptions(int days) async {
    return await _supabase.getExpiringSubscriptions(days);
  }

  @override
  Future<List<Subscription>> getSubscriptionsPaginated(
    int offset,
    int limit,
  ) async {
    return await _supabase.getSubscriptionsPaginated(offset, limit);
  }

  @override
  Future<int> getSubscriptionsCount() async {
    return await _supabase.getSubscriptionsCount();
  }

  @override
  Future<int> getActiveSubscriptionsCount() async {
    return await _supabase.getActiveSubscriptionsCount();
  }

  @override
  Future<double> getTotalRevenue() async {
    return await _supabase.getTotalRevenue();
  }

  @override
  Future<double> getRevenueByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _supabase.getRevenueByDateRange(startDate, endDate);
  }

  @override
  Future<String> createSubscription(Subscription subscription, {bool allowOverlap = false}) async {
    
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Normalize and validate dates (UTC, day precision)
    final startUtc = _normalizeUtcDay(subscription.startDate);
    final endUtc = _normalizeUtcDay(subscription.endDate);
    if (endUtc.isBefore(startUtc)) {
      throw Exception('Start date cannot be after end date.');
    }
    if (!allowOverlap) {
      await _ensureNoOverlapOrThrow(
        studentId: subscription.studentId,
        startUtc: startUtc,
        endUtc: endUtc,
      );
    }

    final subscriptionWithId = Subscription(
      id: id,
      studentId: subscription.studentId,
      planName: subscription.planName,
      startDate: startUtc,
      endDate: endUtc,
      amount: subscription.amount,
      status: subscription.status,
      createdAt: now,
      updatedAt: now,
    );

    await _supabase.createSubscription(subscriptionWithId);
    return id;
  }

  @override
  Future<void> updateSubscription(Subscription subscription, {bool allowOverlap = false}) async {
    
    // Normalize and validate dates
    final startUtc = _normalizeUtcDay(subscription.startDate);
    final endUtc = _normalizeUtcDay(subscription.endDate);
    if (endUtc.isBefore(startUtc)) {
      throw Exception('Start date cannot be after end date.');
    }
    if (!allowOverlap) {
      await _ensureNoOverlapOrThrow(
        studentId: subscription.studentId,
        startUtc: startUtc,
        endUtc: endUtc,
        excludeId: subscription.id,
      );
    }

    final updatedSubscription = Subscription(
      id: subscription.id,
      studentId: subscription.studentId,
      planName: subscription.planName,
      startDate: startUtc,
      endDate: endUtc,
      amount: subscription.amount,
      status: subscription.status,
      createdAt: subscription.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    await _supabase.updateSubscription(updatedSubscription);
  }

  @override
  Future<void> cancelSubscription(String id) async {
    
    await _supabase.cancelSubscription(id);
  }

  @override
  Future<void> renewSubscription(
    String id,
    DateTime newEndDate,
    double amount,
    {bool allowOverlap = false}
  ) async {
    
    // Fetch current subscription for validation
    final current = await _supabase.getSubscriptionById(id);
    if (current == null) return;
    final startUtc = _normalizeUtcDay(current.startDate);
    final endUtc = _normalizeUtcDay(newEndDate);
    if (endUtc.isBefore(startUtc)) {
      throw Exception('End date cannot be before start date.');
    }
    // Ensure no overlaps with other periods for this student
    if (!allowOverlap) {
      await _ensureNoOverlapOrThrow(
        studentId: current.studentId,
        startUtc: startUtc,
        endUtc: endUtc,
        excludeId: id,
      );
    }
    await _supabase.renewSubscription(id, endUtc, amount);
  }

  @override
  Future<void> deleteSubscription(String id) async {
    
    await _supabase.deleteSubscription(id);
  }

  @override
  Stream<List<Subscription>> watchAllSubscriptions() {
    return _supabase.watchAllSubscriptions();
  }

  @override
  Stream<List<Subscription>> watchActiveSubscriptions() {
    return _supabase.watchActiveSubscriptions();
  }

  @override
  Stream<List<Subscription>> watchSubscriptionsByStudent(String studentId) {
    return _supabase.watchSubscriptionsByStudent(studentId);
  }

  @override
  Stream<Subscription?> watchSubscriptionById(String id) {
    return _supabase.watchSubscriptionById(id);
  }
}
