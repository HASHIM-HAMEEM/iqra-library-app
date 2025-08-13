import 'package:equatable/equatable.dart';

enum ActivityType {
  studentCreated,
  studentUpdated,
  studentDeleted,
  studentRestored,
  subscriptionCreated,
  subscriptionUpdated,
  subscriptionCancelled,
  subscriptionRenewed,
  dataBackup,
  dataRestore,
  login,
  logout,
  settingsChanged;

  String get displayName {
    switch (this) {
      case ActivityType.studentCreated:
        return 'Student Created';
      case ActivityType.studentUpdated:
        return 'Student Updated';
      case ActivityType.studentDeleted:
        return 'Student Deleted';
      case ActivityType.studentRestored:
        return 'Student Restored';
      case ActivityType.subscriptionCreated:
        return 'Subscription Created';
      case ActivityType.subscriptionUpdated:
        return 'Subscription Updated';
      case ActivityType.subscriptionCancelled:
        return 'Subscription Cancelled';
      case ActivityType.subscriptionRenewed:
        return 'Subscription Renewed';
      case ActivityType.dataBackup:
        return 'Data Backup';
      case ActivityType.dataRestore:
        return 'Data Restore';
      case ActivityType.login:
        return 'Login';
      case ActivityType.logout:
        return 'Logout';
      case ActivityType.settingsChanged:
        return 'Settings Changed';
    }
  }

  static ActivityType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'student_created':
        return ActivityType.studentCreated;
      case 'student_updated':
        return ActivityType.studentUpdated;
      case 'student_deleted':
        return ActivityType.studentDeleted;
      case 'student_restored':
        return ActivityType.studentRestored;
      case 'subscription_created':
        return ActivityType.subscriptionCreated;
      case 'subscription_updated':
        return ActivityType.subscriptionUpdated;
      case 'subscription_cancelled':
        return ActivityType.subscriptionCancelled;
      case 'subscription_renewed':
        return ActivityType.subscriptionRenewed;
      case 'data_backup':
        return ActivityType.dataBackup;
      case 'data_restore':
        return ActivityType.dataRestore;
      case 'login':
        return ActivityType.login;
      case 'logout':
        return ActivityType.logout;
      case 'settings_changed':
        return ActivityType.settingsChanged;
      default:
        // Return a default activity type instead of throwing an error
        // This prevents the app from crashing if there are unknown activity types in the database
        return ActivityType.settingsChanged;
    }
  }

  String get databaseValue {
    switch (this) {
      case ActivityType.studentCreated:
        return 'student_created';
      case ActivityType.studentUpdated:
        return 'student_updated';
      case ActivityType.studentDeleted:
        return 'student_deleted';
      case ActivityType.studentRestored:
        return 'student_restored';
      case ActivityType.subscriptionCreated:
        return 'subscription_created';
      case ActivityType.subscriptionUpdated:
        return 'subscription_updated';
      case ActivityType.subscriptionCancelled:
        return 'subscription_cancelled';
      case ActivityType.subscriptionRenewed:
        return 'subscription_renewed';
      case ActivityType.dataBackup:
        return 'data_backup';
      case ActivityType.dataRestore:
        return 'data_restore';
      case ActivityType.login:
        return 'login';
      case ActivityType.logout:
        return 'logout';
      case ActivityType.settingsChanged:
        return 'settings_changed';
    }
  }
}

class ActivityLog extends Equatable {
  const ActivityLog({
    required this.id,
    required this.activityType,
    required this.description,
    required this.timestamp,
    this.entityId,
    this.entityType,
    this.metadata,
  });
  final String id;
  final ActivityType activityType;
  final String description;
  final String? entityId;
  final String? entityType;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  ActivityLog copyWith({
    String? id,
    ActivityType? activityType,
    String? description,
    String? entityId,
    String? entityType,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
    id,
    activityType,
    description,
    entityId,
    entityType,
    metadata,
    timestamp,
  ];

  @override
  String toString() {
    return 'ActivityLog(id: $id, type: ${activityType.displayName}, description: $description, timestamp: $formattedTimestamp)';
  }

  // JSON mapping for Supabase rows
  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      activityType: ActivityType.fromString((json['action'] ?? json['activity_type']) as String),
      description: (json['details'] ?? json['description'] ?? '') as String,
      entityId: json['entity_id'] as String?,
      entityType: (json['entity_type'] ?? json['entityType']) as String?,
      // No dedicated metadata column in Supabase schema; keep it null unless your backend encodes it in details
      metadata: null,
      timestamp: DateTime.parse((json['timestamp'] ?? json['created_at']) as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': activityType.databaseValue,
      'details': description,
      'entity_id': entityId,
      'entity_type': entityType,
      // Do not include 'metadata' as the column does not exist in the table
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }
}
