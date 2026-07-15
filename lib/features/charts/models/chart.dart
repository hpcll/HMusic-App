import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/hmusic_track.dart';

part 'chart.g.dart';

// 榜单摘要（GET /charts 列表项）。kind: family|netease|qq|apple，按 kind 字符串分组，
// 保持 String 容错：Server 新增来源时不解码失败，前端分组自然忽略未知组。
@JsonSerializable(includeIfNull: false)
class Chart {
  const Chart({
    required this.id,
    required this.name,
    required this.kind,
    this.description,
  });

  factory Chart.fromJson(Map<String, Object?> json) => _$ChartFromJson(json);

  final String id;
  final String name;
  final String kind;
  final String? description;

  Map<String, Object?> toJson() => _$ChartToJson(this);
}

// 榜单条目。family/wy-*/qq-* 带 track（点了直接播）；apple-* 无 track（前端搜索匹配）。
@JsonSerializable(includeIfNull: false)
class ChartEntry {
  const ChartEntry({
    required this.rank,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    this.playCount,
    this.track,
  });

  factory ChartEntry.fromJson(Map<String, Object?> json) =>
      _$ChartEntryFromJson(json);

  final int rank;
  final String title;
  final String artist;
  final String? album;
  final String? coverUrl;
  final int? playCount;
  final HMusicTrack? track;

  Map<String, Object?> toJson() => _$ChartEntryToJson(this);
}

// 榜单详情（GET /charts/:id）：摘要字段 + updatedAt + entries。
@JsonSerializable(includeIfNull: false)
class ChartDetail {
  const ChartDetail({
    required this.id,
    required this.name,
    required this.kind,
    this.description,
    this.updatedAt,
    this.entries = const <ChartEntry>[],
  });

  factory ChartDetail.fromJson(Map<String, Object?> json) =>
      _$ChartDetailFromJson(json);

  final String id;
  final String name;
  final String kind;
  final String? description;
  final int? updatedAt;
  final List<ChartEntry> entries;

  Map<String, Object?> toJson() => _$ChartDetailToJson(this);

  bool get hasPlayableEntries => entries.any((e) => e.track != null);
}
