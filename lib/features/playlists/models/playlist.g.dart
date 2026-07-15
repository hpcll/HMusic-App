// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaylistSummary _$PlaylistSummaryFromJson(Map<String, dynamic> json) =>
    PlaylistSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      trackCount: (json['trackCount'] as num).toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PlaylistSummaryToJson(PlaylistSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'trackCount': instance.trackCount,
      'description': ?instance.description,
    };

PlaylistItem _$PlaylistItemFromJson(Map<String, dynamic> json) => PlaylistItem(
  id: json['id'] as String,
  track: HMusicTrack.fromJson(json['track'] as Map<String, dynamic>),
  position: (json['position'] as num?)?.toInt(),
  addedAt: (json['addedAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$PlaylistItemToJson(PlaylistItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'track': instance.track,
      'position': ?instance.position,
      'addedAt': ?instance.addedAt,
    };

PlaylistDetail _$PlaylistDetailFromJson(Map<String, dynamic> json) =>
    PlaylistDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      trackCount: (json['trackCount'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => PlaylistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PlaylistItem>[],
    );

Map<String, dynamic> _$PlaylistDetailToJson(PlaylistDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': ?instance.description,
      'trackCount': ?instance.trackCount,
      'createdAt': ?instance.createdAt,
      'updatedAt': ?instance.updatedAt,
      'items': instance.items,
    };
