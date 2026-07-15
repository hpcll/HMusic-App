// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hmusic_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HMusicDevice _$HMusicDeviceFromJson(Map<String, dynamic> json) => HMusicDevice(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String?,
  isDefault: json['isDefault'] as bool? ?? false,
  isOnline: json['isOnline'] as bool? ?? false,
);

Map<String, dynamic> _$HMusicDeviceToJson(HMusicDevice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': ?instance.type,
      'isDefault': instance.isDefault,
      'isOnline': instance.isOnline,
    };
