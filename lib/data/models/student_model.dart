// Removed Drift imports - using Supabase only
import 'package:library_registration_app/domain/entities/student.dart';

class StudentModel {

  const StudentModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.email,
    this.seatNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    this.phone,
    this.address,
    this.profileImagePath,
    this.subscriptionPlan,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionAmount,
    this.subscriptionStatus,
  });

  // JSON mapping for Supabase
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      firstName: (json['first_name'] ?? json['firstName']) as String,
      lastName: (json['last_name'] ?? json['lastName']) as String,
      dateOfBirth: DateTime.parse((json['date_of_birth'] ?? json['dateOfBirth']) as String),
      email: json['email'] as String,
      seatNumber: (json['seat_number'] ?? json['seatNumber']) as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      profileImagePath: (json['profile_image_path'] ?? json['profileImagePath']) as String?,
      createdAt: DateTime.parse((json['created_at'] ?? json['createdAt']) as String),
      updatedAt: DateTime.parse((json['updated_at'] ?? json['updatedAt']) as String),
      isDeleted: (json['is_deleted'] ?? json['isDeleted'] ?? false) as bool,
      subscriptionPlan: (json['subscription_plan'] ?? json['subscriptionPlan']) as String?,
      subscriptionStartDate: ((json['subscription_start_date'] ?? json['subscriptionStartDate']) as String?) != null
          ? DateTime.parse((json['subscription_start_date'] ?? json['subscriptionStartDate']) as String)
          : null,
      subscriptionEndDate: ((json['subscription_end_date'] ?? json['subscriptionEndDate']) as String?) != null
          ? DateTime.parse((json['subscription_end_date'] ?? json['subscriptionEndDate']) as String)
          : null,
      subscriptionAmount: (() {
        final Object? raw = json['subscription_amount'] ?? json['subscriptionAmount'];
        if (raw == null) return null;
        return (raw as num).toDouble();
      })(),
      subscriptionStatus: (json['subscription_status'] ?? json['subscriptionStatus']) as String?,
    );
  }

  // fromDrift method removed - using Supabase only

  // Convert from domain entity to data model
  factory StudentModel.fromEntity(Student student) {
    return StudentModel(
      id: student.id,
      firstName: student.firstName,
      lastName: student.lastName,
      dateOfBirth: student.dateOfBirth,
      email: student.email,
      seatNumber: student.seatNumber,
      phone: student.phone,
      address: student.address,
      profileImagePath: student.profileImagePath,
      createdAt: student.createdAt,
      updatedAt: student.updatedAt,
      isDeleted: student.isDeleted,
      subscriptionPlan: student.subscriptionPlan,
      subscriptionStartDate: student.subscriptionStartDate,
      subscriptionEndDate: student.subscriptionEndDate,
      subscriptionAmount: student.subscriptionAmount,
      subscriptionStatus: student.subscriptionStatus,
    );
  }
  final String id;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String email;
  final String? seatNumber;
  final String? phone;
  final String? address;
  final String? profileImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  // Subscription fields
  final String? subscriptionPlan;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final double? subscriptionAmount;
  final String? subscriptionStatus;

  // toDrift method removed - using Supabase only

  // Convert to domain entity
  Student toEntity() {
    return Student(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      email: email,
      seatNumber: seatNumber,
      phone: phone,
      address: address,
      profileImagePath: profileImagePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      subscriptionPlan: subscriptionPlan,
      subscriptionStartDate: subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate,
      subscriptionAmount: subscriptionAmount,
      subscriptionStatus: subscriptionStatus,
    );
  }

  StudentModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? email,
    String? seatNumber,
    String? phone,
    String? address,
    String? profileImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? subscriptionPlan,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    double? subscriptionAmount,
    String? subscriptionStatus,
  }) {
    return StudentModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      email: email ?? this.email,
      seatNumber: seatNumber ?? this.seatNumber,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      subscriptionAmount: subscriptionAmount ?? this.subscriptionAmount,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth.toUtc().toIso8601String(),
      'email': email,
      'seat_number': seatNumber,
      'phone': phone,
      'address': address,
      'profile_image_path': profileImagePath,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
      'subscription_plan': subscriptionPlan,
      'subscription_start_date': subscriptionStartDate?.toUtc().toIso8601String(),
      'subscription_end_date': subscriptionEndDate?.toUtc().toIso8601String(),
      'subscription_amount': subscriptionAmount,
      'subscription_status': subscriptionStatus,
    };
  }
}
