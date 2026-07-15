// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => ServerInfo(
  name: json['name'] as String,
  version: json['version'] as String,
  apiVersion: json['apiVersion'] as String,
  capabilities:
      (json['capabilities'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as bool),
      ) ??
      const <String, bool>{},
);

Map<String, dynamic> _$ServerInfoToJson(ServerInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'apiVersion': instance.apiVersion,
      'capabilities': instance.capabilities,
    };
