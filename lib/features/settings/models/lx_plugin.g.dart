// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lx_plugin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LxPlugin _$LxPluginFromJson(Map<String, dynamic> json) => LxPlugin(
  id: json['id'] as String,
  name: json['name'] as String,
  enabled: json['enabled'] as bool? ?? true,
  defaultQuality: json['defaultQuality'] as String? ?? '320k',
  sourceUrl: json['sourceUrl'] as String?,
);

Map<String, dynamic> _$LxPluginToJson(LxPlugin instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'enabled': instance.enabled,
  'defaultQuality': instance.defaultQuality,
  'sourceUrl': ?instance.sourceUrl,
};
