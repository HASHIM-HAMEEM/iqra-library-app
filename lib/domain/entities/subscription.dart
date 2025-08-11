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
        throw ArgumentError('Invalid subscription status: $status');
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

  bool get isActive => status == SubscriptionStatus.active && !isExpired;

  bool get isExpired => DateTime.now().isAfter(endDate);

  int get daysRemaining {
    if (isExpired) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  Duration get duration => endDate.difference(startDate);

  double get dailyRate => amount / duration.inDays;

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
}
