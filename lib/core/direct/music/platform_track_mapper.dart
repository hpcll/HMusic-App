import '../../models/hmusic_track.dart';

Map<String, Object?> musicMap(Object? value) =>
    value is Map<String, Object?> ? value : const {};
List<Map<String, Object?>> musicRows(Object? value) => value is List<Object?>
    ? value.whereType<Map<String, Object?>>().toList()
    : const [];
int? musicInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value');

String musicText(Object? value) => (value?.toString() ?? '')
    .replaceAll(RegExp('<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .trim();

class PlatformTrackMapper {
  static HMusicTrack qq(Map<String, Object?> raw) {
    final album = musicMap(raw['album']);
    final media = musicMap(raw['file']);
    final candidates =
        [
              raw['songmid'],
              raw['mid'],
              raw['strMediaMid'],
              media['media_mid'],
              media['mediaMid'],
              raw['songid'],
              raw['id'],
            ]
            .where((value) => value != null && '$value'.isNotEmpty)
            .map((value) => '$value')
            .toList();
    final id =
        candidates.where((id) => !RegExp(r'^\d+$').hasMatch(id)).firstOrNull ??
        candidates.firstOrNull ??
        '';
    final albumMid = album['pmid'] ?? album['mid'] ?? raw['albummid'];
    return HMusicTrack(
      id: 'tx:$id',
      source: 'tx',
      sourceTrackId: id,
      title: musicText(raw['title'] ?? raw['name'] ?? raw['songname']),
      artist: musicRows(
        raw['singer'],
      ).map((s) => musicText(s['name'])).join('/'),
      album: musicText(album['name'] ?? raw['albumname']),
      durationMs: _seconds(raw['interval']),
      coverUrl: albumMid == null || '$albumMid'.isEmpty
          ? null
          : 'https://y.gtimg.cn/music/photo_new/T002R300x300M000$albumMid.jpg',
      raw: raw,
    );
  }

  static HMusicTrack kuwo(Map<String, Object?> raw) {
    final id =
        '${raw['MUSICRID'] ?? raw['rid'] ?? raw['musicrid'] ?? raw['id'] ?? ''}'
            .replaceFirst('MUSIC_', '');
    return HMusicTrack(
      id: 'kw:$id',
      source: 'kw',
      sourceTrackId: id,
      title: musicText(raw['SONGNAME'] ?? raw['name'] ?? raw['songName']),
      artist: musicText(raw['ARTIST'] ?? raw['artist'] ?? raw['artistName']),
      album: musicText(raw['ALBUM'] ?? raw['album']),
      durationMs: _seconds(
        raw['DURATION'] ?? raw['duration'] ?? raw['songTimeMinutes'],
      ),
      coverUrl: (raw['pic'] ?? raw['pic100'] ?? raw['albumpic']) as String?,
      raw: raw,
    );
  }

  static HMusicTrack netease(Map<String, Object?> raw) {
    final id = '${raw['id'] ?? ''}';
    final album = musicMap(raw['al'] ?? raw['album']);
    return HMusicTrack(
      id: 'wy:$id',
      source: 'wy',
      sourceTrackId: id,
      title: musicText(raw['name']),
      artist: musicRows(
        raw['ar'] ?? raw['artists'],
      ).map((s) => musicText(s['name'])).join('/'),
      album: musicText(album['name']),
      durationMs: musicInt(raw['dt'] ?? raw['duration']),
      coverUrl: album['picUrl'] as String?,
      raw: raw,
    );
  }

  static int? _seconds(Object? value) {
    final seconds = musicInt(value);
    if (seconds != null) return seconds * 1000;
    final parts = '$value'.split(':');
    if (parts.length < 2 || parts.any((p) => int.tryParse(p) == null)) {
      return null;
    }
    return parts.fold<int>(0, (sum, p) => sum * 60 + int.parse(p)) * 1000;
  }
}
