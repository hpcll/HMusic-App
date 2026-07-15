import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/hmusic_track.dart';

part 'playlist.g.dart';

// 歌单摘要（GET /playlists 列表项）。
@JsonSerializable(includeIfNull: false)
class PlaylistSummary {
  const PlaylistSummary({
    required this.id,
    required this.name,
    required this.trackCount,
    this.description,
  });

  factory PlaylistSummary.fromJson(Map<String, Object?> json) =>
      _$PlaylistSummaryFromJson(json);

  final String id;
  final String name;
  final int trackCount;
  final String? description;

  Map<String, Object?> toJson() => _$PlaylistSummaryToJson(this);
}

// 歌单曲目条目：itemId（用于按条移除）+ track 快照。
@JsonSerializable(includeIfNull: false)
class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.track,
    this.position,
    this.addedAt,
  });

  factory PlaylistItem.fromJson(Map<String, Object?> json) =>
      _$PlaylistItemFromJson(json);

  final String id;
  final HMusicTrack track;
  final int? position;
  final int? addedAt;

  Map<String, Object?> toJson() => _$PlaylistItemToJson(this);
}

// 歌单详情（GET /playlists/:id 的 { playlist } 内层）。
@JsonSerializable(includeIfNull: false)
class PlaylistDetail {
  const PlaylistDetail({
    required this.id,
    required this.name,
    this.description,
    this.trackCount,
    this.createdAt,
    this.updatedAt,
    this.items = const <PlaylistItem>[],
  });

  factory PlaylistDetail.fromJson(Map<String, Object?> json) =>
      _$PlaylistDetailFromJson(json);

  final String id;
  final String name;
  final String? description;
  final int? trackCount;
  final int? createdAt;
  final int? updatedAt;
  final List<PlaylistItem> items;

  Map<String, Object?> toJson() => _$PlaylistDetailToJson(this);
}

// 导入结果（POST /playlists/import）：用于拼 toast 报告。
class PlaylistImportResult {
  const PlaylistImportResult({
    required this.name,
    required this.imported,
    this.skipDuplicate = 0,
    this.skipEmptyTitle = 0,
    this.skipTruncated = 0,
  });

  factory PlaylistImportResult.fromJson(Map<String, Object?> json) {
    final playlist = json['playlist'];
    final name = playlist is Map<String, Object?>
        ? (playlist['name'] as String? ?? '歌单')
        : '歌单';
    final skipped = json['skipped'];
    int skip(String key) => skipped is Map<String, Object?>
        ? (skipped[key] as num?)?.toInt() ?? 0
        : 0;
    return PlaylistImportResult(
      name: name,
      imported: (json['imported'] as num?)?.toInt() ?? 0,
      skipDuplicate: skip('duplicate'),
      skipEmptyTitle: skip('emptyTitle'),
      skipTruncated: skip('truncated'),
    );
  }

  final String name;
  final int imported;
  final int skipDuplicate;
  final int skipEmptyTitle;
  final int skipTruncated;

  int get skipTotal => skipDuplicate + skipEmptyTitle + skipTruncated;
}
