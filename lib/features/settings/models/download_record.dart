import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/hmusic_track.dart';

part 'download_record.g.dart';

// 下载状态（对齐 web STATUS_LABEL）：排队/下载中/完成/失败。
enum DownloadStatus { pending, downloading, done, failed, unknown }

// 服务端本地下载记录（GET /downloads 列表项）。失败带 error 原因；
// track 快照供重试（POST /downloads {track}）复用。
@JsonSerializable(includeIfNull: false)
class DownloadRecord {
  const DownloadRecord({
    required this.id,
    required this.title,
    required this.status,
    this.artist,
    this.byteSize,
    this.error,
    this.track,
  });

  factory DownloadRecord.fromJson(Map<String, Object?> json) =>
      _$DownloadRecordFromJson(json);

  final String id;
  final String title;

  @JsonKey(unknownEnumValue: DownloadStatus.unknown)
  final DownloadStatus status;

  final String? artist;
  final int? byteSize;
  final String? error;
  final HMusicTrack? track;

  bool get isActive =>
      status == DownloadStatus.pending || status == DownloadStatus.downloading;

  Map<String, Object?> toJson() => _$DownloadRecordToJson(this);
}
