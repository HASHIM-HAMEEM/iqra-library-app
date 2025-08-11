import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/domain/entities/activity_log.dart';

class ActivityLogModel {
  const ActivityLogModel({
    required this.id,
    required this.activityType,
    required this.description,
    required this.timestamp,
    this.entityId,
    this.entityType,
    this.metadata,
  });

  // Convert from Drift model to data model
  factory ActivityLogModel.fromDrift(ActivityLogData activityLog) {
    Map<String, dynamic>? metadata;
    if (activityLog.details != null) {
      try {
        metadata = json.decode(activityLog.details!) as Map<String, dynamic>;
      } catch (e) {
        metadata = null;
      }
    }

    return ActivityLogModel(
      id: activityLog.id,
      activityType: ActivityType.fromString(activityLog.action),
      description: activityLog.details ?? '',
      entityId: activityLog.entityId,
      entityType: activityLog.entityType,
      metadata: metadata,
      timestamp: activityLog.timestamp,
    );
  }

  // Convert from domain entity to data model
  factory ActivityLogModel.fromEntity(ActivityLog activityLog) {
    return ActivityLogModel(
      id: activityLog.id,
      activityType: activityLog.activityType,
      description: activityLog.description,
      entityId: activityLog.entityId,
      entityType: activityLog.entityType,
      metadata: activityLog.metadata,
      timestamp: activityLog.timestamp,
    );
  }
  final String id;
  final ActivityType activityType;
  final String description;
  final String? entityId;
  final String? entityType;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  // Convert to Drift model
  ActivityLogsTableCompanion toDrift() {
    return ActivityLogsTableCompanion.insert(
      id: id,
      action: activityType.databaseValue,
      entityType: entityType ?? '',
      entityId: Value.ofNullable(entityId),
      details: Value.ofNullable(description),
      timestamp: Value(timestamp),
    );
  }

  // Convert to domain entity
  ActivityLog toEntity() {
    return ActivityLog(
      id: id,
      activityType: activityType,
      description: description,
      entityId: entityId,
      entityType: entityType,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  ActivityLogModel copyWith({
    String? id,
    ActivityType? activityType,
    String? description,
    String? entityId,
    String? entityType,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return ActivityLogModel(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
