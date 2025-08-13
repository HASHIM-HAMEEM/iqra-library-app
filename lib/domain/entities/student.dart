
// equatable: ^2.0.5
import 'package:equatable/equatable.dart';

class Student extends Equatable {
  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.address,
    this.profileImagePath,
    this.seatNumber,
    this.isDeleted = false,
    this.subscriptionPlan,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionAmount,
    this.subscriptionStatus,
  });
  final String id;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String email;
  final String? phone;
  final String? address;
  final String? profileImagePath;
  final String? seatNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  // Subscription fields
  final String? subscriptionPlan;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final double? subscriptionAmount;
  final String? subscriptionStatus;

  String get fullName => '$firstName $lastName';

  int get age {
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  String get initials {
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$firstInitial$lastInitial';
  }

  Student copyWith({
    String? id,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? email,
    String? phone,
    String? address,
    String? profileImagePath,
    String? seatNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? subscriptionPlan,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    double? subscriptionAmount,
    String? subscriptionStatus,
  }) {
    return Student(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      seatNumber: seatNumber ?? this.seatNumber,
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

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    dateOfBirth,
    email,
    phone,
    address,
    profileImagePath,
    seatNumber,
    createdAt,
    updatedAt,
    isDeleted,
    subscriptionPlan,
    subscriptionStartDate,
    subscriptionEndDate,
    subscriptionAmount,
    subscriptionStatus,
  ];

  // JSON mapping for Supabase rows
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      firstName: (json['first_name'] ?? json['firstName']) as String,
      lastName: (json['last_name'] ?? json['lastName']) as String,
      dateOfBirth: DateTime.parse((json['date_of_birth'] ?? json['dateOfBirth']) as String),
      email: json['email'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      profileImagePath: (json['profile_image_path'] ?? json['profileImagePath']) as String?,
      seatNumber: (json['seat_number'] ?? json['seatNumber']) as String?,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth.toUtc().toIso8601String(),
      'email': email,
      'phone': phone,
      'address': address,
      'profile_image_path': profileImagePath,
      'seat_number': seatNumber,
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

  @override
  String toString() {
    return 'Student(id: $id, fullName: $fullName, email: $email, age: $age)';
  }
}
