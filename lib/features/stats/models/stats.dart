import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/hmusic_track.dart';

part 'stats.g.dart';

// 听歌统计聚合（GET /stats 的 stats 内层）。图表全部本地渲染（CustomPainter），不引图表库。
@JsonSerializable(includeIfNull: false)
class Stats {
  const Stats({
    required this.overview,
    required this.last30d,
    this.dailyTrend = const <TrendPoint>[],
    this.hourDist = const <HourPoint>[],
    this.sourceDist = const <SourceSlice>[],
    this.topArtists = const <ArtistStat>[],
    this.topTracks = const <TrackStat>[],
    this.topAlbums = const <AlbumStat>[],
  });

  factory Stats.fromJson(Map<String, Object?> json) => _$StatsFromJson(json);

  final StatOverview overview;
  final StatOverview last30d;
  final List<TrendPoint> dailyTrend;
  final List<HourPoint> hourDist;
  final List<SourceSlice> sourceDist;
  final List<ArtistStat> topArtists;
  final List<TrackStat> topTracks;
  final List<AlbumStat> topAlbums;

  Map<String, Object?> toJson() => _$StatsToJson(this);

  bool get isEmpty => overview.totalPlays == 0;
}

@JsonSerializable(includeIfNull: false)
class StatOverview {
  const StatOverview({
    this.totalPlays = 0,
    this.uniqueTracks = 0,
    this.uniqueArtists = 0,
    this.activeDays = 0,
  });

  factory StatOverview.fromJson(Map<String, Object?> json) =>
      _$StatOverviewFromJson(json);

  final int totalPlays;
  final int uniqueTracks;
  final int uniqueArtists;
  final int activeDays;

  Map<String, Object?> toJson() => _$StatOverviewToJson(this);
}

@JsonSerializable(includeIfNull: false)
class TrendPoint {
  const TrendPoint({required this.date, required this.count});

  factory TrendPoint.fromJson(Map<String, Object?> json) =>
      _$TrendPointFromJson(json);

  final String date;
  final int count;

  Map<String, Object?> toJson() => _$TrendPointToJson(this);
}

@JsonSerializable(includeIfNull: false)
class HourPoint {
  const HourPoint({required this.hour, required this.count});

  factory HourPoint.fromJson(Map<String, Object?> json) =>
      _$HourPointFromJson(json);

  final int hour;
  final int count;

  Map<String, Object?> toJson() => _$HourPointToJson(this);
}

@JsonSerializable(includeIfNull: false)
class SourceSlice {
  const SourceSlice({
    required this.source,
    required this.label,
    required this.count,
    required this.percent,
  });

  factory SourceSlice.fromJson(Map<String, Object?> json) =>
      _$SourceSliceFromJson(json);

  final String source;
  final String label;
  final int count;
  final num percent;

  Map<String, Object?> toJson() => _$SourceSliceToJson(this);
}

@JsonSerializable(includeIfNull: false)
class ArtistStat {
  const ArtistStat({required this.name, required this.playCount});

  factory ArtistStat.fromJson(Map<String, Object?> json) =>
      _$ArtistStatFromJson(json);

  final String name;
  final int playCount;

  Map<String, Object?> toJson() => _$ArtistStatToJson(this);
}

@JsonSerializable(includeIfNull: false)
class AlbumStat {
  const AlbumStat({required this.album, required this.playCount});

  factory AlbumStat.fromJson(Map<String, Object?> json) =>
      _$AlbumStatFromJson(json);

  final String album;
  final int playCount;

  Map<String, Object?> toJson() => _$AlbumStatToJson(this);
}

@JsonSerializable(includeIfNull: false)
class TrackStat {
  const TrackStat({
    required this.title,
    required this.artist,
    required this.playCount,
    this.coverUrl,
    this.track,
  });

  factory TrackStat.fromJson(Map<String, Object?> json) =>
      _$TrackStatFromJson(json);

  final String title;
  final String artist;
  final int playCount;
  final String? coverUrl;
  final HMusicTrack? track;

  Map<String, Object?> toJson() => _$TrackStatToJson(this);

  // 点播去重 key（与 web actingKey = title+artist 一致）。
  String get key => '$title$artist';
}
