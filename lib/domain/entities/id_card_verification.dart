import 'package:equatable/equatable.dart';

class IdCardVerification extends Equatable {
  const IdCardVerification({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.seatNumber,
    this.issuedAt,
    this.hasActiveSubscription,
    this.activePlanName,
    this.activeEndDate,
  });

  final String studentId;
  final String firstName;
  final String lastName;
  final String? seatNumber;
  final DateTime? issuedAt;

  /// `true` = active, `false` = not active, `null` = not provided by backend.
  final bool? hasActiveSubscription;
  final String? activePlanName;
  final DateTime? activeEndDate;

  String get fullName => '$firstName $lastName';

  String get shortStudentId =>
      studentId.length >= 8 ? studentId.substring(0, 8).toUpperCase() : studentId.toUpperCase();

  factory IdCardVerification.fromJson(Map<String, dynamic> json) {
    String? readString(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        final value = raw.toString().trim();
        if (value.isNotEmpty) return value;
      }
      return null;
    }

    final id = readString(const ['id', 'student_id', 'studentId']) ?? '';

    var first = readString(const ['first_name', 'firstName']);
    var last = readString(const ['last_name', 'lastName']);

    // Support payloads that return only `full_name`.
    final fullName = readString(const ['full_name', 'fullName']);
    if ((first == null || first.isEmpty) && (last == null || last.isEmpty) && fullName != null) {
      final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        first = parts.first;
        last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }

    if (id.isEmpty || first == null || first.isEmpty) {
      throw StateError('Invalid IdCardVerification payload: missing required fields');
    }

    DateTime? parseDate(Object? raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is String && raw.trim().isNotEmpty) return DateTime.parse(raw);
      return null;
    }

    final hasActive = json['has_active_subscription'] ?? json['hasActiveSubscription'] ?? false;
    final hasActiveProvided =
        json.containsKey('has_active_subscription') || json.containsKey('hasActiveSubscription');
    return IdCardVerification(
      studentId: id,
      firstName: first,
      lastName: last ?? '',
      seatNumber: readString(const ['seat_number', 'seatNumber']),
      issuedAt: parseDate(json['id_card_issued_at'] ?? json['idCardIssuedAt']),
      hasActiveSubscription: hasActiveProvided
          ? (hasActive is bool ? hasActive : (hasActive.toString() == 'true'))
          : null,
      activePlanName: readString(const ['active_plan_name', 'activePlanName']),
      activeEndDate: parseDate(json['active_end_date'] ?? json['activeEndDate']),
    );
  }

  @override
  List<Object?> get props => [
        studentId,
        firstName,
        lastName,
        seatNumber,
        issuedAt,
        hasActiveSubscription,
        activePlanName,
        activeEndDate,
      ];
}
