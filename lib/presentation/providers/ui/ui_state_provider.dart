import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

// Selected tab index for dashboard
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

// Loading state for various operations
final isLoadingProvider = StateProvider<bool>((ref) => false);

// Error message state
final errorMessageProvider = StateProvider<String?>((ref) => null);

// Success message state
final successMessageProvider = StateProvider<String?>((ref) => null);

// Theme mode state
// Theme mode defaults to system. When user explicitly chooses light/dark in Settings,
// we persist that choice; subsequent launches should honor the explicit choice and
// not follow system unless the user selects System again.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Pagination state for students
final studentsPaginationProvider = StateProvider<({int offset, int limit})>(
  (ref) => (offset: 0, limit: 20),
);

// Pagination state for subscriptions
final subscriptionsPaginationProvider =
    StateProvider<({int offset, int limit})>((ref) => (offset: 0, limit: 20));

// Pagination state for activity logs
final activityLogsPaginationProvider = StateProvider<({int offset, int limit})>(
  (ref) => (offset: 0, limit: 50),
);

// Filter state for students
class StudentsFilter {
  const StudentsFilter({
    this.ageRange,
    this.includeDeleted = false,
    this.sortBy = 'name',
    this.sortAscending = true,
  });
  final String? ageRange;
  final bool includeDeleted;
  final String sortBy; // 'name', 'email', 'created_at', 'age'
  final bool sortAscending;

  StudentsFilter copyWith({
    String? ageRange,
    bool? includeDeleted,
    String? sortBy,
    bool? sortAscending,
  }) {
    return StudentsFilter(
      ageRange: ageRange ?? this.ageRange,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

final studentsFilterProvider = StateProvider<StudentsFilter>(
  (ref) => const StudentsFilter(),
);

// Filter state for subscriptions
class SubscriptionsFilter {
  const SubscriptionsFilter({
    this.status,
    this.startDate,
    this.endDate,
    this.sortBy = 'start_date',
    this.sortAscending = false, // Most recent first
  });
  final String? status; // 'active', 'expired', 'cancelled', 'pending'
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortBy; // 'plan_name', 'amount', 'start_date', 'end_date'
  final bool sortAscending;

  SubscriptionsFilter copyWith({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy,
    bool? sortAscending,
  }) {
    return SubscriptionsFilter(
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

final subscriptionsFilterProvider = StateProvider<SubscriptionsFilter>(
  (ref) => const SubscriptionsFilter(),
);

// Filter state for activity logs
class ActivityLogsFilter {
  const ActivityLogsFilter({
    this.activityType,
    this.startDate,
    this.endDate,
    this.entityType,
    this.sortBy = 'timestamp',
    this.sortAscending = false, // Most recent first
  });
  final String? activityType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? entityType;
  final String sortBy; // 'timestamp', 'activity_type'
  final bool sortAscending;

  ActivityLogsFilter copyWith({
    String? activityType,
    DateTime? startDate,
    DateTime? endDate,
    String? entityType,
    String? sortBy,
    bool? sortAscending,
  }) {
    return ActivityLogsFilter(
      activityType: activityType ?? this.activityType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      entityType: entityType ?? this.entityType,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

final activityLogsFilterProvider = StateProvider<ActivityLogsFilter>(
  (ref) => const ActivityLogsFilter(),
);
