// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LibraryItem _$LibraryItemFromJson(Map<String, dynamic> json) => LibraryItem(
  id: json['id'] as String,
  trackKey: json['trackKey'] as String,
  origin: json['origin'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String,
  track: HMusicTrack.fromJson(json['track'] as Map<String, dynamic>),
  album: json['album'] as String?,
  durationMs: (json['durationMs'] as num?)?.toInt(),
  coverUrl: json['coverUrl'] as String?,
  folder: json['folder'] as String? ?? '',
  hasLyric: json['hasLyric'] as bool? ?? false,
  byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$LibraryItemToJson(LibraryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trackKey': instance.trackKey,
      'origin': instance.origin,
      'title': instance.title,
      'artist': instance.artist,
      'album': ?instance.album,
      'durationMs': ?instance.durationMs,
      'coverUrl': ?instance.coverUrl,
      'folder': instance.folder,
      'hasLyric': instance.hasLyric,
      'byteSize': instance.byteSize,
      'track': instance.track,
    };

LibraryScanInfo _$LibraryScanInfoFromJson(Map<String, dynamic> json) =>
    LibraryScanInfo(
      status: json['status'] as String,
      added: (json['added'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      removed: (json['removed'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$LibraryScanInfoToJson(LibraryScanInfo instance) =>
    <String, dynamic>{
      'status': instance.status,
      'added': instance.added,
      'updated': instance.updated,
      'removed': instance.removed,
      'skipped': instance.skipped,
      'error': ?instance.error,
    };
