import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';

// Students list provider
final studentsProvider = StreamProvider<List<Student>>((ref) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.watchActiveStudents();
});

// All students (including deleted) provider
final allStudentsProvider = StreamProvider<List<Student>>((ref) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.watchAllStudents();
});

// Student by ID provider
final studentByIdProvider = StreamProvider.family<Student?, String>((ref, id) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.watchStudentById(id);
});

// Students count provider
final studentsCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.getStudentsCount();
});

// Search students provider
final searchStudentsProvider = FutureProvider.family<List<Student>, String>((
  ref,
  query,
) {
  final repository = ref.watch(studentRepositoryProvider);
  if (query.isEmpty) {
    return repository.getActiveStudents();
  }
  return repository.searchStudents(query);
});

// Recent students provider
final recentStudentsProvider = FutureProvider.family<List<Student>, int>((
  ref,
  days,
) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.getRecentStudents(days);
});

// Students by age range provider
final studentsByAgeRangeProvider =
    FutureProvider.family<List<Student>, ({int minAge, int maxAge})>((
      ref,
      params,
    ) {
      final repository = ref.watch(studentRepositoryProvider);
      return repository.getStudentsByAgeRange(params.minAge, params.maxAge);
    });

// Email exists check provider
final emailExistsProvider =
    FutureProvider.family<bool, ({String email, String? excludeId})>((
      ref,
      params,
    ) {
      final repository = ref.watch(studentRepositoryProvider);
      return repository.isEmailExists(
        params.email,
        excludeId: params.excludeId,
      );
    });
