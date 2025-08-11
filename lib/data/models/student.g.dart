// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Student _$StudentFromJson(Map<String, dynamic> json) => Student(
  id: json['id'] as String,
  firstName: json['firstName'] as String,
  lastName: json['lastName'] as String,
  dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
  email: json['email'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  phone: json['phone'] as String?,
  address: json['address'] as String?,
  profileImagePath: json['profileImagePath'] as String?,
  isDeleted: json['isDeleted'] as bool? ?? false,
  subscriptionPlan: json['subscriptionPlan'] as String?,
  subscriptionStartDate: json['subscriptionStartDate'] == null
      ? null
      : DateTime.parse(json['subscriptionStartDate'] as String),
  subscriptionEndDate: json['subscriptionEndDate'] == null
      ? null
      : DateTime.parse(json['subscriptionEndDate'] as String),
  subscriptionAmount: (json['subscriptionAmount'] as num?)?.toDouble(),
  subscriptionStatus: json['subscriptionStatus'] as String?,
);

Map<String, dynamic> _$StudentToJson(Student instance) => <String, dynamic>{
  'id': instance.id,
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'dateOfBirth': instance.dateOfBirth.toIso8601String(),
  'email': instance.email,
  'phone': instance.phone,
  'address': instance.address,
  'profileImagePath': instance.profileImagePath,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isDeleted': instance.isDeleted,
  'subscriptionPlan': instance.subscriptionPlan,
  'subscriptionStartDate': instance.subscriptionStartDate?.toIso8601String(),
  'subscriptionEndDate': instance.subscriptionEndDate?.toIso8601String(),
  'subscriptionAmount': instance.subscriptionAmount,
  'subscriptionStatus': instance.subscriptionStatus,
};
