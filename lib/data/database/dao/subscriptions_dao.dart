import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/database/tables/students_table.dart';
import 'package:library_registration_app/data/database/tables/subscriptions_table.dart';

part 'subscriptions_dao.g.dart';

@DriftAccessor(tables: [SubscriptionsTable, StudentsTable])
class SubscriptionsDao extends DatabaseAccessor<AppDatabase>
    with _$SubscriptionsDaoMixin {
  SubscriptionsDao(super.db);

  // Get all subscriptions
  Future<List<SubscriptionData>> getAllSubscriptions() {
    return (select(subscriptionsTable)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  // Get subscription by ID
  Future<SubscriptionData?> getSubscriptionById(String id) {
    return (select(
      subscriptionsTable,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  // Get subscriptions for a specific student
  Future<List<SubscriptionData>> getSubscriptionsByStudentId(String studentId) {
    return (select(subscriptionsTable)
          ..where((tbl) => tbl.studentId.equals(studentId))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get active subscription for a student
  Future<SubscriptionData?> getActiveSubscriptionByStudentId(String studentId) {
    return (select(subscriptionsTable)
          ..where(
            (tbl) =>
                tbl.studentId.equals(studentId) & tbl.status.equals('active'),
          )
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  // Get subscriptions by status
  Future<List<SubscriptionData>> getSubscriptionsByStatus(String status) {
    return (select(subscriptionsTable)
          ..where((tbl) => tbl.status.equals(status))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get expiring subscriptions (within specified days)
  Future<List<SubscriptionData>> getExpiringSubscriptions({
    int withinDays = 7,
  }) {
    final cutoffDate = DateTime.now().add(Duration(days: withinDays));

    return (select(subscriptionsTable)
          ..where(
            (tbl) =>
                tbl.status.equals('active') &
                tbl.endDate.isNotNull() &
                tbl.endDate.isSmallerOrEqualValue(cutoffDate),
          )
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.endDate)]))
        .get();
  }

  // Get expired subscriptions
  Future<List<SubscriptionData>> getExpiredSubscriptions() {
    final now = DateTime.now();

    return (select(subscriptionsTable)
          ..where(
            (tbl) =>
                (tbl.status.equals('expired')) |
                (tbl.status.equals('active') &
                    tbl.endDate.isNotNull() &
                    tbl.endDate.isSmallerThanValue(now)),
          )
          ..orderBy([
            (tbl) =>
                OrderingTerm(expression: tbl.endDate, mode: OrderingMode.desc),
          ]))
        .get();
  }

  // Get subscriptions with pagination
  Future<List<SubscriptionData>> getSubscriptionsWithPagination({
    required int limit,
    required int offset,
    String? status,
  }) {
    var query = select(subscriptionsTable);

    if (status != null) {
      query = query..where((tbl) => tbl.status.equals(status));
    }

    return (query
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  // Get subscription statistics
  Future<Map<String, int>> getSubscriptionStatistics() async {
    final activeCount = await _getCountByStatus('active');
    final expiredCount = await _getCountByStatus('expired');
    final cancelledCount = await _getCountByStatus('cancelled');
    final pendingCount = await _getCountByStatus('pending');

    return {
      'active': activeCount,
      'expired': expiredCount,
      'cancelled': cancelledCount,
      'pending': pendingCount,
      'total': activeCount + expiredCount + cancelledCount + pendingCount,
    };
  }

  Future<int> _getCountByStatus(String status) async {
    final countExp = countAll();
    final query = selectOnly(subscriptionsTable)
      ..addColumns([countExp])
      ..where(subscriptionsTable.status.equals(status));

    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // Get revenue statistics
  Future<Map<String, double>> getRevenueStatistics() async {
    final totalRevenue = await _getTotalRevenueByStatus(null);
    final activeRevenue = await _getTotalRevenueByStatus('active');
    final monthlyRevenue = await _getMonthlyRevenue();

    return {
      'total': totalRevenue,
      'active': activeRevenue,
      'monthly': monthlyRevenue,
    };
  }

  Future<double> _getTotalRevenueByStatus(String? status) async {
    final sumExp = subscriptionsTable.amount.sum();
    var query = selectOnly(subscriptionsTable)..addColumns([sumExp]);

    if (status != null) {
      query = query..where(subscriptionsTable.status.equals(status));
    }

    final result = await query.getSingle();
    return result.read(sumExp) ?? 0.0;
  }

  Future<double> _getMonthlyRevenue() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final sumExp = subscriptionsTable.amount.sum();
    final query = selectOnly(subscriptionsTable)
      ..addColumns([sumExp])
      ..where(
        subscriptionsTable.createdAt.isBetweenValues(startOfMonth, endOfMonth),
      );

    final result = await query.getSingle();
    return result.read(sumExp) ?? 0.0;
  }

  // Insert new subscription
  Future<int> insertSubscription(SubscriptionsTableCompanion subscription) {
    return into(subscriptionsTable).insert(subscription);
  }

  // Update subscription
  Future<bool> updateSubscription(
    String id,
    SubscriptionsTableCompanion subscription,
  ) async {
    final updatedRows =
        await (update(subscriptionsTable)..where((tbl) => tbl.id.equals(id)))
            .write(subscription.copyWith(updatedAt: Value(DateTime.now())));
    return updatedRows > 0;
  }

  // Update subscription status
  Future<bool> updateSubscriptionStatus(String id, String status) async {
    final updatedRows =
        await (update(
          subscriptionsTable,
        )..where((tbl) => tbl.id.equals(id))).write(
          SubscriptionsTableCompanion(
            status: Value(status),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return updatedRows > 0;
  }

  // Cancel subscription
  Future<bool> cancelSubscription(String id) async {
    return updateSubscriptionStatus(id, 'cancelled');
  }

  // Renew subscription
  Future<bool> renewSubscription(String id, DateTime newEndDate) async {
    final updatedRows =
        await (update(
          subscriptionsTable,
        )..where((tbl) => tbl.id.equals(id))).write(
          SubscriptionsTableCompanion(
            endDate: Value(newEndDate),
            status: const Value('active'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return updatedRows > 0;
  }

  // Delete subscription
  Future<bool> deleteSubscription(String id) async {
    final deletedRows = await (delete(
      subscriptionsTable,
    )..where((tbl) => tbl.id.equals(id))).go();
    return deletedRows > 0;
  }

  // Auto-expire subscriptions
  Future<int> autoExpireSubscriptions() async {
    final now = DateTime.now();

    final updatedRows =
        await (update(subscriptionsTable)..where(
              (tbl) =>
                  tbl.status.equals('active') &
                  tbl.endDate.isNotNull() &
                  tbl.endDate.isSmallerThanValue(now),
            ))
            .write(
              SubscriptionsTableCompanion(
                status: const Value('expired'),
                updatedAt: Value(now),
              ),
            );

    return updatedRows;
  }

  // Get subscription with student details (join query)
  Future<List<Map<String, dynamic>>>
  getSubscriptionsWithStudentDetails() async {
    final query = select(subscriptionsTable).join([
      innerJoin(
        studentsTable,
        studentsTable.id.equalsExp(subscriptionsTable.studentId),
      ),
    ]);

    final results = await query.get();

    return results.map((row) {
      final subscription = row.readTable(subscriptionsTable);
      final student = row.readTable(studentsTable);

      return {'subscription': subscription, 'student': student};
    }).toList();
  }

  // Watch subscriptions by student ID
  Stream<List<SubscriptionData>> watchSubscriptionsByStudent(String studentId) {
    return (select(subscriptionsTable)
          ..where((tbl) => tbl.studentId.equals(studentId))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  // Watch subscription by ID
  Stream<SubscriptionData?> watchSubscriptionById(String id) {
    return (select(
      subscriptionsTable,
    )..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }

  // Watch all subscriptions
  Stream<List<SubscriptionData>> watchAllSubscriptions() {
    return (select(subscriptionsTable)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // Watch active subscriptions
  Stream<List<SubscriptionData>> watchActiveSubscriptions() {
    return (select(subscriptionsTable)
          ..where((tbl) => tbl.status.equals('active'))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  // Get total revenue
  Future<double> getTotalRevenue() async {
    return _getTotalRevenueByStatus(null);
  }

  // Get revenue by date range
  Future<double> getRevenueByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sumExp = subscriptionsTable.amount.sum();
    final query = selectOnly(subscriptionsTable)
      ..addColumns([sumExp])
      ..where(subscriptionsTable.createdAt.isBetweenValues(startDate, endDate));

    final result = await query.getSingle();
    return result.read(sumExp) ?? 0.0;
  }

  // Get subscriptions count
  Future<int> getSubscriptionsCount() async {
    final countExp = countAll();
    final query = selectOnly(subscriptionsTable)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // Get active subscriptions count
  Future<int> getActiveSubscriptionsCount() async {
    final countExp = countAll();
    final query = selectOnly(subscriptionsTable)
      ..addColumns([countExp])
      ..where(subscriptionsTable.status.equals('active'));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // Get active subscriptions
  Future<List<SubscriptionData>> getActiveSubscriptions() {
    return getSubscriptionsByStatus('active');
  }

  // Get subscriptions by student
  Future<List<SubscriptionData>> getSubscriptionsByStudent(String studentId) {
    return getSubscriptionsByStudentId(studentId);
  }

  // Get active subscription by student
  Future<SubscriptionData?> getActiveSubscriptionByStudent(String studentId) {
    return getActiveSubscriptionByStudentId(studentId);
  }

  // Get subscriptions paginated
  Future<List<SubscriptionData>> getSubscriptionsPaginated(
    int offset,
    int limit,
  ) {
    return getSubscriptionsWithPagination(limit: limit, offset: offset);
  }
}
