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
    this.idCardToken,
    this.idCardIssuedAt,
  });

  // JSON mapping for Supabase rows
  factory Student.fromJson(Map<String, dynamic> json) {
    String readString(
      List<String> keys, {
      String fallback = '',
      bool trim = false,
    }) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        final value = raw.toString();
        return trim ? value.trim() : value;
      }
      return fallback;
    }

    DateTime readDate(
      List<String> keys, {
      required DateTime fallback,
    }) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is DateTime) return raw;
        final text = raw.toString().trim();
        if (text.isEmpty) continue;
        final parsed = DateTime.tryParse(text);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    DateTime? readNullableDate(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is DateTime) return raw;
        final text = raw.toString().trim();
        if (text.isEmpty) continue;
        final parsed = DateTime.tryParse(text);
        if (parsed != null) return parsed;
      }
      return null;
    }

    bool readBool(List<String> keys, {bool fallback = false}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is bool) return raw;
        final text = raw.toString().toLowerCase().trim();
        if (text == 'true' || text == '1') return true;
        if (text == 'false' || text == '0') return false;
      }
      return fallback;
    }

    double? readNullableDouble(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is num) return raw.toDouble();
        final parsed = double.tryParse(raw.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    final nowUtc = DateTime.now().toUtc();
    return Student(
      id: readString(const ['id'], trim: true),
      firstName: readString(const ['first_name', 'firstName'], trim: true),
      lastName: readString(const ['last_name', 'lastName'], trim: true),
      dateOfBirth: readDate(
        const ['date_of_birth', 'dateOfBirth'],
        fallback: DateTime(1970).toUtc(),
      ),
      email: readString(const ['email'], trim: true),
      phone: readString(const ['phone']).trim().isEmpty
          ? null
          : readString(const ['phone']).trim(),
      address: readString(const ['address']).trim().isEmpty
          ? null
          : readString(const ['address']).trim(),
      profileImagePath:
          readString(const ['profile_image_path', 'profileImagePath'])
                  .trim()
                  .isEmpty
          ? null
          : readString(const ['profile_image_path', 'profileImagePath']).trim(),
      seatNumber:
          readString(const ['seat_number', 'seatNumber']).trim().isEmpty
          ? null
          : readString(const ['seat_number', 'seatNumber']).trim(),
      createdAt: readDate(
        const ['created_at', 'createdAt'],
        fallback: nowUtc,
      ),
      updatedAt: readDate(
        const ['updated_at', 'updatedAt'],
        fallback: nowUtc,
      ),
      isDeleted: readBool(const ['is_deleted', 'isDeleted']),
      subscriptionPlan:
          readString(const ['subscription_plan', 'subscriptionPlan'])
                  .trim()
                  .isEmpty
          ? null
          : readString(const ['subscription_plan', 'subscriptionPlan']).trim(),
      subscriptionStartDate: readNullableDate(
        const ['subscription_start_date', 'subscriptionStartDate'],
      ),
      subscriptionEndDate: readNullableDate(
        const ['subscription_end_date', 'subscriptionEndDate'],
      ),
      subscriptionAmount: readNullableDouble(
        const ['subscription_amount', 'subscriptionAmount'],
      ),
      subscriptionStatus:
          readString(const ['subscription_status', 'subscriptionStatus'])
                  .trim()
                  .isEmpty
          ? null
          : readString(const ['subscription_status', 'subscriptionStatus']).trim(),
      idCardToken:
          readString(const ['id_card_token', 'idCardToken']).trim().isEmpty
          ? null
          : readString(const ['id_card_token', 'idCardToken']).trim(),
      idCardIssuedAt: readNullableDate(
        const ['id_card_issued_at', 'idCardIssuedAt'],
      ),
    );
  }
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
  final String? idCardToken;
  final DateTime? idCardIssuedAt;

  String get fullName => '$firstName $lastName';

  int get age {
    final now = DateTime.now();
    var a = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      a--;
    }
    return a;
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
    String? idCardToken,
    DateTime? idCardIssuedAt,
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
      idCardToken: idCardToken ?? this.idCardToken,
      idCardIssuedAt: idCardIssuedAt ?? this.idCardIssuedAt,
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
    idCardToken,
    idCardIssuedAt,
  ];

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
      'subscription_start_date': subscriptionStartDate
          ?.toUtc()
          .toIso8601String(),
      'subscription_end_date': subscriptionEndDate?.toUtc().toIso8601String(),
      'subscription_amount': subscriptionAmount,
      'subscription_status': subscriptionStatus,
      'id_card_token': idCardToken,
      'id_card_issued_at': idCardIssuedAt?.toUtc().toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Student(id: $id, fullName: $fullName, email: $email, age: $age)';
  }
}
