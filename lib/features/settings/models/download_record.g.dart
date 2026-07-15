// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadRecord _$DownloadRecordFromJson(Map<String, dynamic> json) =>
    DownloadRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      status: $enumDecode(
        _$DownloadStatusEnumMap,
        json['status'],
        unknownValue: DownloadStatus.unknown,
      ),
      artist: json['artist'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt(),
      error: json['error'] as String?,
      track: json['track'] == null
          ? null
          : HMusicTrack.fromJson(json['track'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DownloadRecordToJson(DownloadRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'status': _$DownloadStatusEnumMap[instance.status]!,
      'artist': ?instance.artist,
      'byteSize': ?instance.byteSize,
      'error': ?instance.error,
      'track': ?instance.track,
    };

const _$DownloadStatusEnumMap = {
  DownloadStatus.pending: 'pending',
  DownloadStatus.downloading: 'downloading',
  DownloadStatus.done: 'done',
  DownloadStatus.failed: 'failed',
  DownloadStatus.unknown: 'unknown',
};
