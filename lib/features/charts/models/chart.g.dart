// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chart _$ChartFromJson(Map<String, dynamic> json) => Chart(
  id: json['id'] as String,
  name: json['name'] as String,
  kind: json['kind'] as String,
  description: json['description'] as String?,
);

Map<String, dynamic> _$ChartToJson(Chart instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'kind': instance.kind,
  'description': ?instance.description,
};

ChartEntry _$ChartEntryFromJson(Map<String, dynamic> json) => ChartEntry(
  rank: (json['rank'] as num).toInt(),
  title: json['title'] as String,
  artist: json['artist'] as String,
  album: json['album'] as String?,
  coverUrl: json['coverUrl'] as String?,
  playCount: (json['playCount'] as num?)?.toInt(),
  track: json['track'] == null
      ? null
      : HMusicTrack.fromJson(json['track'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ChartEntryToJson(ChartEntry instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'title': instance.title,
      'artist': instance.artist,
      'album': ?instance.album,
      'coverUrl': ?instance.coverUrl,
      'playCount': ?instance.playCount,
      'track': ?instance.track,
    };

ChartDetail _$ChartDetailFromJson(Map<String, dynamic> json) => ChartDetail(
  id: json['id'] as String,
  name: json['name'] as String,
  kind: json['kind'] as String,
  description: json['description'] as String?,
  updatedAt: (json['updatedAt'] as num?)?.toInt(),
  entries:
      (json['entries'] as List<dynamic>?)
          ?.map((e) => ChartEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ChartEntry>[],
);

Map<String, dynamic> _$ChartDetailToJson(ChartDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'kind': instance.kind,
      'description': ?instance.description,
      'updatedAt': ?instance.updatedAt,
      'entries': instance.entries,
    };
