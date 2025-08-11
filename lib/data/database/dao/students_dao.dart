import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/database/tables/students_table.dart';

part 'students_dao.g.dart';

@DriftAccessor(tables: [StudentsTable])
class StudentsDao extends DatabaseAccessor<AppDatabase>
    with _$StudentsDaoMixin {
  StudentsDao(super.db);

  // Get all active students (not deleted)
  Future<List<StudentData>> getAllActiveStudents() {
    return (select(studentsTable)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.firstName),
            (tbl) => OrderingTerm(expression: tbl.lastName),
          ]))
        .get();
  }

  // Get student by ID
  Future<StudentData?> getStudentById(String id) {
    return (select(studentsTable)
          ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  // Get student by email
  Future<StudentData?> getStudentByEmail(String email) {
    return (select(studentsTable)..where(
          (tbl) => tbl.email.equals(email) & tbl.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  // Search students by name or email
  Future<List<StudentData>> searchStudents(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    final seatTerm = '%$query%';
    return (select(studentsTable)
          ..where(
            (tbl) =>
                tbl.isDeleted.equals(false) &
                (tbl.firstName.lower().like(searchTerm) |
                    tbl.lastName.lower().like(searchTerm) |
                    tbl.email.lower().like(searchTerm) |
                    // For nullable seat numbers, only include when not null
                    (tbl.seatNumber.isNotNull() & tbl.seatNumber.like(seatTerm))),
          )
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.firstName),
            (tbl) => OrderingTerm(expression: tbl.lastName),
          ]))
        .get();
  }

  // Get students with pagination
  Future<List<StudentData>> getStudentsWithPagination({
    required int limit,
    required int offset,
  }) {
    return (select(studentsTable)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  // Get total count of active students
  Future<int> getActiveStudentsCount() async {
    final countExp = countAll();
    final query = selectOnly(studentsTable)
      ..addColumns([countExp])
      ..where(studentsTable.isDeleted.equals(false));

    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // Insert new student
  Future<int> insertStudent(StudentsTableCompanion student) {
    return into(studentsTable).insert(student);
  }

  // Update student
  Future<bool> updateStudent(String id, StudentsTableCompanion student) async {
    final updatedRows =
        await (update(studentsTable)..where((tbl) => tbl.id.equals(id))).write(
          student.copyWith(updatedAt: Value(DateTime.now())),
        );
    return updatedRows > 0;
  }

  // Soft delete student
  Future<bool> softDeleteStudent(String id) async {
    final updatedRows =
        await (update(studentsTable)..where((tbl) => tbl.id.equals(id))).write(
          StudentsTableCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return updatedRows > 0;
  }

  // Hard delete student (permanent)
  Future<bool> hardDeleteStudent(String id) async {
    final deletedRows = await (delete(
      studentsTable,
    )..where((tbl) => tbl.id.equals(id))).go();
    return deletedRows > 0;
  }

  // Restore soft-deleted student
  Future<bool> restoreStudent(String id) async {
    final updatedRows =
        await (update(studentsTable)..where((tbl) => tbl.id.equals(id))).write(
          StudentsTableCompanion(
            isDeleted: const Value(false),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return updatedRows > 0;
  }

  // Check if email exists (excluding specific student ID)
  Future<bool> isEmailExists(String email, {String? excludeStudentId}) async {
    var query = select(studentsTable)
      ..where((tbl) => tbl.email.equals(email) & tbl.isDeleted.equals(false));

    if (excludeStudentId != null) {
      query = query..where((tbl) => tbl.id.equals(excludeStudentId).not());
    }

    final result = await query.getSingleOrNull();
    return result != null;
  }

  // Get students by age range
  Future<List<StudentData>> getStudentsByAgeRange({
    required int minAge,
    required int maxAge,
  }) {
    final now = DateTime.now();
    final maxBirthDate = DateTime(now.year - minAge, now.month, now.day);
    final minBirthDate = DateTime(now.year - maxAge - 1, now.month, now.day);

    return (select(studentsTable)
          ..where(
            (tbl) =>
                tbl.isDeleted.equals(false) &
                tbl.dateOfBirth.isBetweenValues(minBirthDate, maxBirthDate),
          )
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.dateOfBirth,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Get recently added students
  Future<List<StudentData>> getRecentlyAddedStudents({int limit = 10}) {
    return (select(studentsTable)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .get();
  }

  // Clear all students
  Future<int> clearAllStudents() async {
    return delete(studentsTable).go();
  }

  // Watch student by ID
  Stream<StudentData?> watchStudentById(String id) {
    return (select(
      studentsTable,
    )..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }

  // Get students count
  Future<int> getStudentsCount() async {
    final countExp = countAll();
    final query = selectOnly(studentsTable)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  // Get recent students
  Future<List<StudentData>> getRecentStudents(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return (select(studentsTable)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(cutoffDate))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // Watch all students
  Stream<List<StudentData>> watchAllStudents() {
    return (select(studentsTable)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // Watch active students
  Stream<List<StudentData>> watchActiveStudents() {
    return (select(studentsTable)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<List<StudentData>> getAllStudents() {
    return (select(studentsTable)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<List<StudentData>> getActiveStudents() {
    return (select(studentsTable)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<StudentData>> getStudentsPaginated(int offset, int limit) {
    return (select(studentsTable)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit, offset: offset))
        .get();
  }
}
