// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLog _$ActivityLogFromJson(Map<String, dynamic> json) => ActivityLog(
  id: json['id'] as String,
  action: json['action'] as String,
  entityType: $enumDecode(_$EntityTypeEnumMap, json['entityType']),
  timestamp: DateTime.parse(json['timestamp'] as String),
  entityId: json['entityId'] as String?,
  details: json['details'] as Map<String, dynamic>?,
  userId: json['userId'] as String?,
);

Map<String, dynamic> _$ActivityLogToJson(ActivityLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'action': instance.action,
      'entityType': _$EntityTypeEnumMap[instance.entityType]!,
      'entityId': instance.entityId,
      'details': instance.details,
      'timestamp': instance.timestamp.toIso8601String(),
      'userId': instance.userId,
    };

const _$EntityTypeEnumMap = {
  EntityType.student: 'student',
  EntityType.subscription: 'subscription',
  EntityType.backup: 'backup',
  EntityType.settings: 'settings',
  EntityType.auth: 'auth',
  EntityType.system: 'system',
};
