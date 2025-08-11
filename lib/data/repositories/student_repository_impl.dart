import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/models/student_model.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/repositories/student_repository.dart';
import 'package:uuid/uuid.dart';

class StudentRepositoryImpl implements StudentRepository {
  StudentRepositoryImpl(this._database);
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<Student>> getAllStudents() async {
    final students = await _database.studentsDao.getAllStudents();
    return students.map((s) => StudentModel.fromDrift(s).toEntity()).toList();
  }

  @override
  Future<List<Student>> getActiveStudents() async {
    final students = await _database.studentsDao.getActiveStudents();
    return students.map((s) => StudentModel.fromDrift(s).toEntity()).toList();
  }

  @override
  Future<Student?> getStudentById(String id) async {
    final student = await _database.studentsDao.getStudentById(id);
    return student != null ? StudentModel.fromDrift(student).toEntity() : null;
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    final students = await _database.studentsDao.searchStudents(query);
    return students.map((s) => StudentModel.fromDrift(s).toEntity()).toList();
  }

  @override
  Future<List<Student>> getStudentsPaginated(int offset, int limit) async {
    final students = await _database.studentsDao.getStudentsPaginated(
      offset,
      limit,
    );
    return students.map((s) => StudentModel.fromDrift(s).toEntity()).toList();
  }

  @override
  Future<int> getStudentsCount() async {
    return _database.studentsDao.getStudentsCount();
  }

  @override
  Future<bool> isEmailExists(String email, {String? excludeId}) async {
    return _database.studentsDao.isEmailExists(email);
  }

  @override
  Future<List<Student>> getStudentsByAgeRange(int minAge, int maxAge) async {
    final students = await _database.studentsDao.getStudentsByAgeRange(
      minAge: minAge,
      maxAge: maxAge,
    );
    return students.map((s) => StudentModel.fromDrift(s).toEntity()).toList();
  }

  @override
  Future<List<Student>> getRecentStudents(int days) async {
    final students = await _database.studentsDao.getRecentStudents(days);
    return students.map((s) => StudentModel.fromDrift(s).toEntity()).toList();
  }

  @override
  Future<String> createStudent(Student student) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final studentModel = StudentModel(
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
      isDeleted: false,
    );

    await _database.studentsDao.insertStudent(studentModel.toDrift());
    return id;
  }

  @override
  Future<void> updateStudent(Student student) async {
    final studentModel = StudentModel(
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
    );

    await _database.studentsDao.updateStudent(
      studentModel.id,
      studentModel.toDrift(),
    );
  }

  @override
  Future<void> deleteStudent(String id, {bool hard = false}) async {
    if (hard) {
      await _database.studentsDao.hardDeleteStudent(id);
    } else {
      await _database.studentsDao.softDeleteStudent(id);
    }
  }

  @override
  Future<void> restoreStudent(String id) async {
    await _database.studentsDao.restoreStudent(id);
  }

  @override
  Stream<List<Student>> watchAllStudents() {
    return _database.studentsDao.watchAllStudents().map(
      (students) =>
          students.map((s) => StudentModel.fromDrift(s).toEntity()).toList(),
    );
  }

  @override
  Stream<List<Student>> watchActiveStudents() {
    return _database.studentsDao.watchActiveStudents().map(
      (students) =>
          students.map((s) => StudentModel.fromDrift(s).toEntity()).toList(),
    );
  }

  @override
  Stream<Student?> watchStudentById(String id) {
    return _database.studentsDao
        .watchStudentById(id)
        .map(
          (student) => student != null
              ? StudentModel.fromDrift(student).toEntity()
              : null,
        );
  }
}
