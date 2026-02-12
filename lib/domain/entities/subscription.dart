import 'package:equatable/equatable.dart';

enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  pending;

  String get displayName {
    switch (this) {
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

  static SubscriptionStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'pending':
        return SubscriptionStatus.pending;
      default:
        // Graceful fallback for unknown status instead of crashing
        return SubscriptionStatus.pending;
    }
  }
}

class Subscription extends Equatable {
  const Subscription({
    required this.id,
    required this.studentId,
    required this.planName,
    required this.startDate,
    required this.endDate,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String studentId;
  final String planName;
  final DateTime startDate;
  final DateTime endDate;
  final double amount;
  final SubscriptionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive {
    final now = DateTime.now().toUtc();
    return status == SubscriptionStatus.active &&
        !now.isBefore(startDate.toUtc()) &&
        !now.isAfter(endDate.toUtc());
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(endDate.toUtc());

  int get daysRemaining {
    if (isExpired) return 0;
    return endDate.toUtc().difference(DateTime.now().toUtc()).inDays;
  }

  Duration get duration => endDate.difference(startDate);

  double get dailyRate => duration.inDays > 0 ? amount / duration.inDays : 0.0;

  Subscription copyWith({
    String? id,
    String? studentId,
    String? planName,
    DateTime? startDate,
    DateTime? endDate,
    double? amount,
    SubscriptionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      planName: planName ?? this.planName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    planName,
    startDate,
    endDate,
    amount,
    status,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() {
    return 'Subscription(id: $id, planName: $planName, status: ${status.displayName}, daysRemaining: $daysRemaining)';
  }

  // JSON mapping for Supabase rows
  factory Subscription.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        final text = raw.toString().trim();
        if (text.isEmpty) continue;
        return text;
      }
      return fallback;
    }

    DateTime readDate(List<String> keys, {required DateTime fallback}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is DateTime) return raw;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    double readDouble(List<String> keys, {double fallback = 0.0}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is num) return raw.toDouble();
        final parsed = double.tryParse(raw.toString());
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final nowUtc = DateTime.now().toUtc();
    final startDate = readDate(
      const ['start_date', 'subscription_start_date', 'startDate'],
      fallback: nowUtc,
    );
    final endDate = readDate(
      const ['end_date', 'subscription_end_date', 'endDate'],
      fallback: startDate,
    );

    return Subscription(
      id: readString(const ['id']),
      studentId: readString(const ['student_id', 'studentId']),
      planName: readString(const ['plan_name', 'planName']),
      startDate: startDate,
      endDate: endDate,
      amount: readDouble(const ['amount', 'subscription_amount']),
      status: SubscriptionStatus.fromString(
        readString(const ['status', 'subscription_status'], fallback: 'pending'),
      ),
      createdAt: readDate(
        const ['created_at', 'createdAt'],
        fallback: nowUtc,
      ),
      updatedAt: readDate(
        const ['updated_at', 'updatedAt'],
        fallback: nowUtc,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'plan_name': planName,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'amount': amount,
      'status': status.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
