// import 'package:library_registration_app/data/models/student_model.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/repositories/student_repository.dart';
import 'package:uuid/uuid.dart';

class StudentRepositoryImpl implements StudentRepository {
  StudentRepositoryImpl(this._supabase);
  final SupabaseService _supabase;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<Student>> getAllStudents() async {
    return _supabase.getAllStudents();
  }

  @override
  Future<List<Student>> getActiveStudents() async {
    return _supabase.getActiveStudents();
  }

  @override
  Future<List<Student>> getDiscardedStudentsPaginated(int offset, int limit) async {
    return _supabase.getDiscardedStudentsPaginated(offset, limit);
  }

  @override
  Future<Student?> getStudentById(String id) async {
    return _supabase.getStudentById(id);
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    return _supabase.searchStudents(query);
  }

  @override
  Future<List<Student>> getStudentsPaginated(int offset, int limit) async {
    return _supabase.getStudentsPaginated(offset, limit);
  }

  @override
  Future<int> getStudentsCount() async {
    return _supabase.getStudentsCount();
  }

  @override
  Future<bool> isEmailExists(String email, {String? excludeId}) async {
    return _supabase.isEmailExists(email, excludeId: excludeId);
  }

  @override
  Future<List<Student>> getStudentsByAgeRange(int minAge, int maxAge) async {
    return _supabase.getStudentsByAgeRange(minAge, maxAge);
  }

  @override
  Future<List<Student>> getRecentStudents(int days) async {
    return _supabase.getRecentStudents(days);
  }

  @override
  Future<String> createStudent(Student student) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    // Always ensure a secure, unique token exists so ID card verification works
    // even if the database enforces NOT NULL/UNIQUE constraints for this field.
    final token =
        (student.idCardToken?.trim().isNotEmpty ?? false)
            ? student.idCardToken!.trim()
            : _uuid.v4().replaceAll('-', '');
    final issuedAt = student.idCardIssuedAt ?? now;

    final studentWithId = Student(
      id: id,
      firstName: student.firstName,
      lastName: student.lastName,
      dateOfBirth: student.dateOfBirth,
      email: student.email,
      seatNumber: student.seatNumber,
      phone: student.phone,
      address: student.address,
      profileImagePath: student.profileImagePath,
      createdAt: now,
      updatedAt: now,
      idCardToken: token,
      idCardIssuedAt: issuedAt,
    );

    await _supabase.createStudent(studentWithId);
    return id;
  }

  @override
  Future<void> updateStudent(Student student) async {
    final updatedStudent = Student(
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
      updatedAt: DateTime.now(),
      isDeleted: student.isDeleted,
      subscriptionPlan: student.subscriptionPlan,
      subscriptionStartDate: student.subscriptionStartDate,
      subscriptionEndDate: student.subscriptionEndDate,
      subscriptionAmount: student.subscriptionAmount,
      subscriptionStatus: student.subscriptionStatus,
      idCardToken: student.idCardToken,
      idCardIssuedAt: student.idCardIssuedAt,
    );

    await _supabase.updateStudent(updatedStudent);
  }

  @override
  Future<void> deleteStudent(String id, {bool hard = false}) async {
    await _supabase.deleteStudent(id, hard: hard);
  }

  @override
  Future<void> restoreStudent(String id) async {
    await _supabase.restoreStudent(id);
  }

  @override
  Stream<List<Student>> watchAllStudents() {
    return _supabase.watchAllStudents();
  }

  @override
  Stream<List<Student>> watchActiveStudents() {
    return _supabase.watchActiveStudents();
  }

  @override
  Stream<Student?> watchStudentById(String id) {
    return _supabase.watchStudentById(id);
  }
}
