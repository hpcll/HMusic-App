// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hmusic_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HMusicTrack _$HMusicTrackFromJson(Map<String, dynamic> json) => HMusicTrack(
  id: json['id'] as String,
  source: json['source'] as String,
  sourceTrackId: json['sourceTrackId'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String,
  album: json['album'] as String?,
  durationMs: (json['durationMs'] as num?)?.toInt(),
  coverUrl: json['coverUrl'] as String?,
  url: json['url'] as String?,
  qualities:
      (json['qualities'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  raw: json['raw'],
);

Map<String, dynamic> _$HMusicTrackToJson(HMusicTrack instance) =>
    <String, dynamic>{
      'id': instance.id,
      'source': instance.source,
      'sourceTrackId': instance.sourceTrackId,
      'title': instance.title,
      'artist': instance.artist,
      'album': ?instance.album,
      'durationMs': ?instance.durationMs,
      'coverUrl': ?instance.coverUrl,
      'url': ?instance.url,
      'qualities': instance.qualities,
      'raw': ?instance.raw,
    };
