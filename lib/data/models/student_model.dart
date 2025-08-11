import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/app_database.dart';
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

  // Convert from Drift model to data model
  factory StudentModel.fromDrift(StudentData student) {
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

  // Convert to Drift model
  StudentsTableCompanion toDrift() {
    return StudentsTableCompanion.insert(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      email: email,
      seatNumber: Value(seatNumber),
      phone: Value(phone),
      address: Value(address),
      profileImagePath: Value(profileImagePath),
      subscriptionPlan: Value(subscriptionPlan),
      subscriptionStartDate: Value(subscriptionStartDate),
      subscriptionEndDate: Value(subscriptionEndDate),
      subscriptionAmount: Value(subscriptionAmount),
      subscriptionStatus: Value(subscriptionStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

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
}
