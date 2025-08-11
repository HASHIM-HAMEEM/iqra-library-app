// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSetting _$AppSettingFromJson(Map<String, dynamic> json) => AppSetting(
  key: json['key'] as String,
  value: json['value'] as String,
  type: $enumDecode(_$SettingTypeEnumMap, json['type']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  description: json['description'] as String?,
);

Map<String, dynamic> _$AppSettingToJson(AppSetting instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'type': _$SettingTypeEnumMap[instance.type]!,
      'description': instance.description,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$SettingTypeEnumMap = {
  SettingType.string: 'string',
  SettingType.integer: 'int',
  SettingType.double: 'double',
  SettingType.boolean: 'bool',
  SettingType.json: 'json',
};
