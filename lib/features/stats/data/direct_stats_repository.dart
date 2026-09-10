import '../../../core/direct/music/platform_track_mapper.dart';
import '../../../core/direct/storage/direct_local_store.dart';
import '../../../core/models/hmusic_track.dart';
import '../models/stats.dart';
import 'stats_repository.dart';

class DirectStatsRepository implements StatsRepository {
  DirectStatsRepository(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DirectLocalStore _store;
  final DateTime Function() _now;

  @override
  Future<Stats> getStats() async {
    final events = musicRows((await _store.read('history'))['events'])
        .where(
          (event) =>
              event['track'] is Map && musicInt(event['playedAt']) != null,
        )
        .toList();
    final now = _now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final recent = events
        .where(
          (event) =>
              musicInt(event['playedAt'])! >= start.millisecondsSinceEpoch,
        )
        .toList();
    final daily = <String, int>{},
        hours = <int, int>{},
        sources = <String, int>{};
    final tracks = <String, (HMusicTrack, int)>{},
        artists = <String, int>{},
        albums = <String, int>{};
    for (final event in events) {
      final track = HMusicTrack.fromJson(musicMap(event['track']));
      final time = DateTime.fromMillisecondsSinceEpoch(
        musicInt(event['playedAt'])!,
      );
      tracks[track.id] = (track, (tracks[track.id]?.$2 ?? 0) + 1);
      artists.update(track.artist, (count) => count + 1, ifAbsent: () => 1);
      if (track.album?.isNotEmpty == true) {
        albums.update(track.album!, (count) => count + 1, ifAbsent: () => 1);
      }
      sources.update(track.source, (count) => count + 1, ifAbsent: () => 1);
      hours.update(time.hour, (count) => count + 1, ifAbsent: () => 1);
      daily.update(_date(time), (count) => count + 1, ifAbsent: () => 1);
    }
    final ranked = tracks.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    final artistList = artists.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final albumList = albums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Stats(
      overview: _overview(events),
      last30d: _overview(recent),
      dailyTrend: [
        for (var i = 0; i < 30; i++)
          TrendPoint(
            date: _date(start.add(Duration(days: i))),
            count: daily[_date(start.add(Duration(days: i)))] ?? 0,
          ),
      ],
      hourDist: [
        for (var hour = 0; hour < 24; hour++)
          HourPoint(hour: hour, count: hours[hour] ?? 0),
      ],
      sourceDist: [
        for (final entry in sources.entries)
          SourceSlice(
            source: entry.key,
            label: switch (entry.key) {
              'tx' => 'QQ 音乐',
              'kw' => '酷我',
              'wy' => '网易云音乐',
              'manual' => '手工曲目',
              _ => entry.key,
            },
            count: entry.value,
            percent: events.isEmpty ? 0 : entry.value * 100 / events.length,
          ),
      ],
      topTracks: [
        for (final (track, count) in ranked.take(20))
          TrackStat(
            title: track.title,
            artist: track.artist,
            playCount: count,
            coverUrl: track.coverUrl,
            track: track,
          ),
      ],
      topArtists: [
        for (final entry in artistList.take(20))
          ArtistStat(name: entry.key, playCount: entry.value),
      ],
      topAlbums: [
        for (final entry in albumList.take(20))
          AlbumStat(album: entry.key, playCount: entry.value),
      ],
    );
  }

  StatOverview _overview(List<Map<String, Object?>> events) {
    final tracks = events
        .map((event) => HMusicTrack.fromJson(musicMap(event['track'])))
        .toList();
    return StatOverview(
      totalPlays: events.length,
      uniqueTracks: tracks.map((t) => t.id).toSet().length,
      uniqueArtists: tracks
          .map((t) => t.artist)
          .where((a) => a.isNotEmpty)
          .toSet()
          .length,
      activeDays: events
          .map(
            (event) => _date(
              DateTime.fromMillisecondsSinceEpoch(musicInt(event['playedAt'])!),
            ),
          )
          .toSet()
          .length,
    );
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
