
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

  @override
  String toString() {
    return 'Student(id: $id, fullName: $fullName, email: $email, age: $age)';
  }
}
