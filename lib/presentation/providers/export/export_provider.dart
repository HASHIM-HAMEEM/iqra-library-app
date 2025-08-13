import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:library_registration_app/data/services/export_service.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';
import 'package:library_registration_app/domain/entities/student.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';
import 'package:library_registration_app/presentation/providers/activity_logs/activity_logs_provider.dart';
import 'package:library_registration_app/presentation/providers/students/students_provider.dart';
import 'package:library_registration_app/presentation/providers/subscriptions/subscriptions_provider.dart';

part 'export_provider.g.dart';

enum ExportType {
  all,
  students,
  subscriptions,
  activityLogs,
}

enum ExportStatus {
  idle,
  loading,
  success,
  error,
}

class ExportState {
  const ExportState({
    this.status = ExportStatus.idle,
    this.filePath,
    this.errorMessage,
    this.progress = 0.0,
  });

  final ExportStatus status;
  final String? filePath;
  final String? errorMessage;
  final double progress;

  ExportState copyWith({
    ExportStatus? status,
    String? filePath,
    String? errorMessage,
    double? progress,
  }) {
    return ExportState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

@riverpod
ExportService exportService(ExportServiceRef ref) {
  return ExportService();
}

@riverpod
class ExportNotifier extends _$ExportNotifier {
  @override
  ExportState build() {
    return const ExportState();
  }

  Future<void> exportData(ExportType type) async {
    try {
      state = state.copyWith(status: ExportStatus.loading, progress: 0.0);

      final exportService = ref.read(exportServiceProvider);
      String filePath;

      switch (type) {
        case ExportType.all:
          filePath = await _exportAllData(exportService);
          break;
        case ExportType.students:
          filePath = await _exportStudentsOnly(exportService);
          break;
        case ExportType.subscriptions:
          filePath = await _exportSubscriptionsOnly(exportService);
          break;
        case ExportType.activityLogs:
          filePath = await _exportActivityLogsOnly(exportService);
          break;
      }

      state = state.copyWith(
        status: ExportStatus.success,
        filePath: filePath,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        errorMessage: e.toString(),
        progress: 0.0,
      );
    }
  }

  Future<String> _exportAllData(ExportService exportService) async {
    // Update progress
    state = state.copyWith(progress: 0.1);

    // Fetch all data
    final studentsAsync = await ref.read(studentsProvider.future);
    state = state.copyWith(progress: 0.3);

    final subscriptionsAsync = await ref.read(subscriptionsProvider.future);
    state = state.copyWith(progress: 0.5);

    final activityLogsAsync = await ref.read(activityLogsProvider.future);
    state = state.copyWith(progress: 0.7);

    // Generate Excel file
    final filePath = await exportService.exportAllData(
      students: studentsAsync,
      subscriptions: subscriptionsAsync,
      activityLogs: activityLogsAsync,
    );
    
    state = state.copyWith(progress: 0.9);
    return filePath;
  }

  Future<String> _exportStudentsOnly(ExportService exportService) async {
    state = state.copyWith(progress: 0.2);
    
    final students = await ref.read(studentsProvider.future);
    state = state.copyWith(progress: 0.6);
    
    final filePath = await exportService.exportStudentsData(students);
    state = state.copyWith(progress: 0.9);
    
    return filePath;
  }

  Future<String> _exportSubscriptionsOnly(ExportService exportService) async {
    state = state.copyWith(progress: 0.2);
    
    final subscriptions = await ref.read(subscriptionsProvider.future);
    state = state.copyWith(progress: 0.6);
    
    final filePath = await exportService.exportSubscriptionsData(subscriptions);
    state = state.copyWith(progress: 0.9);
    
    return filePath;
  }

  Future<String> _exportActivityLogsOnly(ExportService exportService) async {
    state = state.copyWith(progress: 0.2);
    
    final activityLogs = await ref.read(activityLogsProvider.future);
    state = state.copyWith(progress: 0.6);
    
    final filePath = await exportService.exportActivityLogsData(activityLogs);
    state = state.copyWith(progress: 0.9);
    
    return filePath;
  }

  Future<void> shareExportedFile() async {
    if (state.filePath != null) {
      final exportService = ref.read(exportServiceProvider);
      await exportService.shareExportedFile(state.filePath!);
    }
  }

  void resetState() {
    state = const ExportState();
  }
}

@riverpod
Future<List<Student>> allStudentsForExport(AllStudentsForExportRef ref) async {
  return ref.watch(studentsProvider.future);
}

@riverpod
Future<List<Subscription>> allSubscriptionsForExport(AllSubscriptionsForExportRef ref) async {
  return ref.watch(subscriptionsProvider.future);
}

@riverpod
Future<List<ActivityLog>> allActivityLogsForExport(AllActivityLogsForExportRef ref) async {
  return ref.watch(activityLogsProvider.future);
}

@riverpod
Future<Map<String, int>> exportDataCounts(ExportDataCountsRef ref) async {
  final students = await ref.watch(allStudentsForExportProvider.future);
  final subscriptions = await ref.watch(allSubscriptionsForExportProvider.future);
  final activityLogs = await ref.watch(allActivityLogsForExportProvider.future);

  return {
    'students': students.length,
    'subscriptions': subscriptions.length,
    'activityLogs': activityLogs.length,
    'activeSubscriptions': subscriptions.where((s) => s.status == 'active').length,
    'expiredSubscriptions': subscriptions.where((s) => s.status == 'expired').length,
  };
}