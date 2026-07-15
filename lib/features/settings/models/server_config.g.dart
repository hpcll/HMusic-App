// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerConfig _$ServerConfigFromJson(Map<String, dynamic> json) => ServerConfig(
  serverName: json['serverName'] as String,
  defaultQuality: json['defaultQuality'] as String,
  searchStrategy: json['searchStrategy'] as String,
  resolveStrategy: json['resolveStrategy'] as String,
  extraPlayMusicModels:
      (json['extraPlayMusicModels'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  manualTracks:
      (json['manualTracks'] as List<dynamic>?)
          ?.map((e) => ManualTrack.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ServerConfigToJson(ServerConfig instance) =>
    <String, dynamic>{
      'serverName': instance.serverName,
      'defaultQuality': instance.defaultQuality,
      'searchStrategy': instance.searchStrategy,
      'resolveStrategy': instance.resolveStrategy,
      'extraPlayMusicModels': instance.extraPlayMusicModels,
      'manualTracks': instance.manualTracks,
    };

ManualTrack _$ManualTrackFromJson(Map<String, dynamic> json) => ManualTrack(
  title: json['title'] as String,
  url: json['url'] as String,
  artist: json['artist'] as String?,
);

Map<String, dynamic> _$ManualTrackToJson(ManualTrack instance) =>
    <String, dynamic>{
      'title': instance.title,
      'artist': ?instance.artist,
      'url': instance.url,
    };
