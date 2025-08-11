import 'package:library_registration_app/domain/entities/student.dart';

abstract class StudentRepository {
  Future<List<Student>> getAllStudents();
  Future<List<Student>> getActiveStudents();
  Future<Student?> getStudentById(String id);
  Future<List<Student>> searchStudents(String query);
  Future<List<Student>> getStudentsPaginated(int offset, int limit);
  Future<int> getStudentsCount();
  Future<bool> isEmailExists(String email, {String? excludeId});
  Future<List<Student>> getStudentsByAgeRange(int minAge, int maxAge);
  Future<List<Student>> getRecentStudents(int days);

  Future<String> createStudent(Student student);
  Future<void> updateStudent(Student student);
  Future<void> deleteStudent(String id, {bool hard = false});
  Future<void> restoreStudent(String id);

  Stream<List<Student>> watchAllStudents();
  Stream<List<Student>> watchActiveStudents();
  Stream<Student?> watchStudentById(String id);
}
