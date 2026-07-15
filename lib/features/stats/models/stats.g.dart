// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Stats _$StatsFromJson(Map<String, dynamic> json) => Stats(
  overview: StatOverview.fromJson(json['overview'] as Map<String, dynamic>),
  last30d: StatOverview.fromJson(json['last30d'] as Map<String, dynamic>),
  dailyTrend:
      (json['dailyTrend'] as List<dynamic>?)
          ?.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TrendPoint>[],
  hourDist:
      (json['hourDist'] as List<dynamic>?)
          ?.map((e) => HourPoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <HourPoint>[],
  sourceDist:
      (json['sourceDist'] as List<dynamic>?)
          ?.map((e) => SourceSlice.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SourceSlice>[],
  topArtists:
      (json['topArtists'] as List<dynamic>?)
          ?.map((e) => ArtistStat.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ArtistStat>[],
  topTracks:
      (json['topTracks'] as List<dynamic>?)
          ?.map((e) => TrackStat.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TrackStat>[],
  topAlbums:
      (json['topAlbums'] as List<dynamic>?)
          ?.map((e) => AlbumStat.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AlbumStat>[],
);

Map<String, dynamic> _$StatsToJson(Stats instance) => <String, dynamic>{
  'overview': instance.overview,
  'last30d': instance.last30d,
  'dailyTrend': instance.dailyTrend,
  'hourDist': instance.hourDist,
  'sourceDist': instance.sourceDist,
  'topArtists': instance.topArtists,
  'topTracks': instance.topTracks,
  'topAlbums': instance.topAlbums,
};

StatOverview _$StatOverviewFromJson(Map<String, dynamic> json) => StatOverview(
  totalPlays: (json['totalPlays'] as num?)?.toInt() ?? 0,
  uniqueTracks: (json['uniqueTracks'] as num?)?.toInt() ?? 0,
  uniqueArtists: (json['uniqueArtists'] as num?)?.toInt() ?? 0,
  activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$StatOverviewToJson(StatOverview instance) =>
    <String, dynamic>{
      'totalPlays': instance.totalPlays,
      'uniqueTracks': instance.uniqueTracks,
      'uniqueArtists': instance.uniqueArtists,
      'activeDays': instance.activeDays,
    };

TrendPoint _$TrendPointFromJson(Map<String, dynamic> json) => TrendPoint(
  date: json['date'] as String,
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$TrendPointToJson(TrendPoint instance) =>
    <String, dynamic>{'date': instance.date, 'count': instance.count};

HourPoint _$HourPointFromJson(Map<String, dynamic> json) => HourPoint(
  hour: (json['hour'] as num).toInt(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$HourPointToJson(HourPoint instance) => <String, dynamic>{
  'hour': instance.hour,
  'count': instance.count,
};

SourceSlice _$SourceSliceFromJson(Map<String, dynamic> json) => SourceSlice(
  source: json['source'] as String,
  label: json['label'] as String,
  count: (json['count'] as num).toInt(),
  percent: json['percent'] as num,
);

Map<String, dynamic> _$SourceSliceToJson(SourceSlice instance) =>
    <String, dynamic>{
      'source': instance.source,
      'label': instance.label,
      'count': instance.count,
      'percent': instance.percent,
    };

ArtistStat _$ArtistStatFromJson(Map<String, dynamic> json) => ArtistStat(
  name: json['name'] as String,
  playCount: (json['playCount'] as num).toInt(),
);

Map<String, dynamic> _$ArtistStatToJson(ArtistStat instance) =>
    <String, dynamic>{'name': instance.name, 'playCount': instance.playCount};

AlbumStat _$AlbumStatFromJson(Map<String, dynamic> json) => AlbumStat(
  album: json['album'] as String,
  playCount: (json['playCount'] as num).toInt(),
);

Map<String, dynamic> _$AlbumStatToJson(AlbumStat instance) => <String, dynamic>{
  'album': instance.album,
  'playCount': instance.playCount,
};

TrackStat _$TrackStatFromJson(Map<String, dynamic> json) => TrackStat(
  title: json['title'] as String,
  artist: json['artist'] as String,
  playCount: (json['playCount'] as num).toInt(),
  coverUrl: json['coverUrl'] as String?,
  track: json['track'] == null
      ? null
      : HMusicTrack.fromJson(json['track'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TrackStatToJson(TrackStat instance) => <String, dynamic>{
  'title': instance.title,
  'artist': instance.artist,
  'playCount': instance.playCount,
  'coverUrl': ?instance.coverUrl,
  'track': ?instance.track,
};
