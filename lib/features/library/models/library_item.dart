import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/hmusic_track.dart';

part 'library_item.g.dart';

// NAS 曲库条目（GET /library items[]）：元数据 + 服务端拼好的可播 track
//（track.url 为签名本地代理地址，直接 POST /playback/play 短路直播）。
@JsonSerializable(includeIfNull: false)
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.trackKey,
    required this.origin,
    required this.title,
    required this.artist,
    required this.track,
    this.album,
    this.durationMs,
    this.coverUrl,
    this.folder = '',
    this.hasLyric = false,
    this.byteSize = 0,
  });

  factory LibraryItem.fromJson(Map<String, Object?> json) =>
      _$LibraryItemFromJson(json);

  final String id;
  final String trackKey;
  final String origin; // scan | upload | download
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? coverUrl;

  // 所在目录（相对扫描根，"" = 根目录直属）与是否已刮到歌词。
  final String folder;
  final bool hasLyric;
  final int byteSize;
  final HMusicTrack track;

  Map<String, Object?> toJson() => _$LibraryItemToJson(this);
}

// 扫描进度（GET /library 与 POST /library/scan 均返回）。
@JsonSerializable(includeIfNull: false)
class LibraryScanInfo {
  const LibraryScanInfo({
    required this.status,
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.skipped = 0,
    this.error,
  });

  factory LibraryScanInfo.fromJson(Map<String, Object?> json) =>
      _$LibraryScanInfoFromJson(json);

  final String status; // idle | scanning | done | failed
  final int added;
  final int updated;
  final int removed;
  final int skipped;
  final String? error;

  bool get isScanning => status == 'scanning';

  Map<String, Object?> toJson() => _$LibraryScanInfoToJson(this);
}

// 歌手/专辑聚合条目（GET /library/groups）。
class LibraryGroup {
  const LibraryGroup({required this.name, required this.count});

  factory LibraryGroup.fromJson(Map<String, Object?> json) => LibraryGroup(
    name: (json['name'] as String?) ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final int count;
}

// GET /library 一页结果。
class LibraryListResult {
  const LibraryListResult({
    required this.items,
    required this.total,
    this.scan,
  });

  factory LibraryListResult.fromJson(Map<String, Object?> json) {
    return LibraryListResult(
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, Object?>>()
          .map(LibraryItem.fromJson)
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      scan: json['scan'] is Map<String, Object?>
          ? LibraryScanInfo.fromJson(json['scan']! as Map<String, Object?>)
          : null,
    );
  }

  final List<LibraryItem> items;
  final int total;
  final LibraryScanInfo? scan;
}
