import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/models/subscription_model.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/domain/repositories/subscription_repository.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._database);
  final AppDatabase _database;
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
    final existing = await _database.subscriptionsDao.getSubscriptionsByStudentId(studentId);
    for (final sub in existing) {
      if (excludeId != null && sub.id == excludeId) continue;
      final s = _normalizeUtcDay(sub.startDate);
      final e = _normalizeUtcDay((sub.endDate ?? sub.startDate));
      if (_rangesOverlap(startUtc, endUtc, s, e)) {
        final df = DateFormat('dd MMM yyyy');
        final range = '${df.format(s.toLocal())} to ${df.format(e.toLocal())}';
        throw Exception('This overlaps an existing subscription from $range.');
      }
    }
  }

  @override
  Future<List<Subscription>> getAllSubscriptions() async {
    final subscriptions = await _database.subscriptionsDao
        .getAllSubscriptions();
    return subscriptions
        .map((s) => SubscriptionModel.fromDrift(s).toEntity())
        .toList();
  }

  @override
  Future<List<Subscription>> getActiveSubscriptions() async {
    final subscriptions = await _database.subscriptionsDao
        .getActiveSubscriptions();
    return subscriptions
        .map((s) => SubscriptionModel.fromDrift(s).toEntity())
        .toList();
  }

  @override
  Future<List<Subscription>> getExpiredSubscriptions() async {
    final subscriptions = await _database.subscriptionsDao
        .getExpiredSubscriptions();
    return subscriptions
        .map((s) => SubscriptionModel.fromDrift(s).toEntity())
        .toList();
  }

  @override
  Future<List<Subscription>> getSubscriptionsByStatus(
    SubscriptionStatus status,
  ) async {
    final subscriptions = await _database.subscriptionsDao
        .getSubscriptionsByStatus(status.name);
    return subscriptions
        .map((s) => SubscriptionModel.fromDrift(s).toEntity())
        .toList();
  }

  @override
  Future<List<Subscription>> getSubscriptionsByStudent(String studentId) async {
    final subscriptions = await _database.subscriptionsDao
        .getSubscriptionsByStudent(studentId);
    return subscriptions
        .map((s) => SubscriptionModel.fromDrift(s).toEntity())
        .toList();
  }

  @override
  Future<Subscription?> getSubscriptionById(String id) async {
    final subscription = await _database.subscriptionsDao.getSubscriptionById(
      id,
    );
    return subscription != null
        ? SubscriptionModel.fromDrift(subscription).toEntity()
        : null;
  }

  @override
  Future<Subscription?> getActiveSubscriptionByStudent(String studentId) async {
    final subscription = await _database.subscriptionsDao
        .getActiveSubscriptionByStudent(studentId);
    return subscription != null
        ? SubscriptionModel.fromDrift(subscription).toEntity()
        : null;
  }

  @override
  Future<List<Subscription>> getExpiringSubscriptions(int days) async {
    final subscriptions = await _database.subscriptionsDao
        .getExpiringSubscriptions(withinDays: days);
    return subscriptions
        .map((s) => SubscriptionModel.fromDrift(s).toEntity())
        .toList();
  }

  @override
  Future<List<Subscription>> getSubscriptionsPaginated(
    int offset,
    int limit,
  ) async {
    final subscriptions = await _database.subscriptionsDao
        .getSubscriptionsPaginated(offset, limit);
    return subscriptions
        .map((s) => SubscriptionModel.fromDrift(s).toEntity())
        .toList();
  }

  @override
  Future<int> getSubscriptionsCount() async {
    return _database.subscriptionsDao.getSubscriptionsCount();
  }

  @override
  Future<int> getActiveSubscriptionsCount() async {
    return _database.subscriptionsDao.getActiveSubscriptionsCount();
  }

  @override
  Future<double> getTotalRevenue() async {
    return _database.subscriptionsDao.getTotalRevenue();
  }

  @override
  Future<double> getRevenueByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _database.subscriptionsDao.getRevenueByDateRange(startDate, endDate);
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

    final subscriptionModel = SubscriptionModel(
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

    await _database.subscriptionsDao.insertSubscription(
      subscriptionModel.toDrift(),
    );
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

    final subscriptionModel = SubscriptionModel(
      id: subscription.id,
      studentId: subscription.studentId,
      planName: subscription.planName,
      startDate: startUtc,
      endDate: endUtc,
      amount: subscription.amount,
      status: subscription.status,
      createdAt: subscription.createdAt.toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await _database.subscriptionsDao.updateSubscription(
      subscriptionModel.id,
      subscriptionModel.toDrift(),
    );
  }

  @override
  Future<void> cancelSubscription(String id) async {
    await _database.subscriptionsDao.cancelSubscription(id);
  }

  @override
  Future<void> renewSubscription(
    String id,
    DateTime newEndDate,
    double amount,
    {bool allowOverlap = false}
  ) async {
    // Fetch current subscription for validation
    final current = await _database.subscriptionsDao.getSubscriptionById(id);
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
    await _database.subscriptionsDao.renewSubscription(id, endUtc);
  }

  @override
  Future<void> deleteSubscription(String id) async {
    await _database.subscriptionsDao.deleteSubscription(id);
  }

  @override
  Stream<List<Subscription>> watchAllSubscriptions() {
    return _database.subscriptionsDao.watchAllSubscriptions().map(
      (subscriptions) => subscriptions
          .map((s) => SubscriptionModel.fromDrift(s).toEntity())
          .toList(),
    );
  }

  @override
  Stream<List<Subscription>> watchActiveSubscriptions() {
    return _database.subscriptionsDao.watchActiveSubscriptions().map(
      (subscriptions) => subscriptions
          .map((s) => SubscriptionModel.fromDrift(s).toEntity())
          .toList(),
    );
  }

  @override
  Stream<List<Subscription>> watchSubscriptionsByStudent(String studentId) {
    return _database.subscriptionsDao
        .watchSubscriptionsByStudent(studentId)
        .map(
          (subscriptions) => subscriptions
              .map((s) => SubscriptionModel.fromDrift(s).toEntity())
              .toList(),
        );
  }

  @override
  Stream<Subscription?> watchSubscriptionById(String id) {
    return _database.subscriptionsDao
        .watchSubscriptionById(id)
        .map(
          (subscription) => subscription != null
              ? SubscriptionModel.fromDrift(subscription).toEntity()
              : null,
        );
  }
}
