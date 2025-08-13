// Removed Drift imports - using Supabase only
import 'package:library_registration_app/domain/entities/subscription.dart';

class SubscriptionModel {
  const SubscriptionModel({
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

  // fromDrift method removed - using Supabase only

  // Convert from domain entity to data model
  factory SubscriptionModel.fromEntity(Subscription subscription) {
    return SubscriptionModel(
      id: subscription.id,
      studentId: subscription.studentId,
      planName: subscription.planName,
      startDate: subscription.startDate,
      endDate: subscription.endDate,
      amount: subscription.amount,
      status: subscription.status,
      createdAt: subscription.createdAt,
      updatedAt: subscription.updatedAt,
    );
  }
  final String id;
  final String studentId;
  final String planName;
  final DateTime startDate;
  final DateTime endDate;
  final double amount;
  final SubscriptionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // toDrift method removed - using Supabase only

  // Convert to domain entity
  Subscription toEntity() {
    return Subscription(
      id: id,
      studentId: studentId,
      planName: planName,
      // Convert to local for display/logic
      startDate: startDate.toLocal(),
      endDate: endDate.toLocal(),
      amount: amount,
      status: status,
      createdAt: createdAt.toLocal(),
      updatedAt: updatedAt.toLocal(),
    );
  }

  SubscriptionModel copyWith({
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
    return SubscriptionModel(
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
}
