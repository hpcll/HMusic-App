import '../../../core/direct/music/platform_track_mapper.dart';
import '../../../core/models/hmusic_track.dart';
import '../models/chart.dart';

List<ChartEntry> directFamilyEntries(
  Map<String, Object?> history,
  DateTime now,
) {
  final since = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  final until = now.millisecondsSinceEpoch;
  final grouped = <String, ({HMusicTrack track, int count, int lastAt})>{};
  for (final event in musicRows(history['events'])) {
    final at = musicInt(event['playedAt']);
    final raw = musicMap(event['track']);
    if (at == null || at < since || at > until || raw['id'] is! String) {
      continue;
    }
    final track = HMusicTrack.fromJson(raw);
    if (track.sourceTrackId == 'hmusic-test-tone') continue;
    final key = '${track.source}:${track.sourceTrackId}';
    final old = grouped[key];
    grouped[key] = (
      track: old == null || at >= old.lastAt ? track : old.track,
      count: (old?.count ?? 0) + 1,
      lastAt: old == null || at > old.lastAt ? at : old.lastAt,
    );
  }
  final sorted = grouped.values.toList()
    ..sort((a, b) {
      final count = b.count.compareTo(a.count);
      return count == 0 ? b.lastAt.compareTo(a.lastAt) : count;
    });
  return [
    for (final (index, item) in sorted.take(50).indexed)
      chartEntryForTrack(item.track, index + 1, playCount: item.count),
  ];
}

ChartEntry chartEntryForTrack(HMusicTrack track, int rank, {int? playCount}) =>
    ChartEntry(
      rank: rank,
      title: track.title,
      artist: track.artist,
      album: track.album,
      coverUrl: track.coverUrl,
      playCount: playCount,
      track: track,
    );
