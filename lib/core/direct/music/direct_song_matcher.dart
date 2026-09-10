import '../../models/hmusic_track.dart';

/// 迁移旧版标题/歌手/时长匹配；明确拒绝不同歌手和 live/伴奏版本。
HMusicTrack? matchDirectSong(
  HMusicTrack original,
  List<HMusicTrack> candidates,
) {
  String normalized(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[\s·•\-()\[\]【】（）]'), '');
  final title = normalized(original.title),
      artist = normalized(original.artist);
  for (final candidate in candidates.take(10)) {
    if (normalized(candidate.title) != title) continue;
    final other = normalized(candidate.artist);
    if (artist.isNotEmpty &&
        other != artist &&
        !original.artist
            .split('/')
            .any((name) => name.isNotEmpty && other == normalized(name))) {
      continue;
    }
    if (original.durationMs != null &&
        candidate.durationMs != null &&
        (original.durationMs! - candidate.durationMs!).abs() > 15000) {
      continue;
    }
    return candidate;
  }
  return null;
}
