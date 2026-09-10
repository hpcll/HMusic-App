import '../music/platform_track_mapper.dart';

/// 小米位置和时长位于 play_song_detail，单位为毫秒；缺失值不可当作零。
class MiSpeakerStatus {
  MiSpeakerStatus(Map<String, Object?> info)
    : status = musicInt(info['status']),
      volume = musicInt(info['volume']),
      positionMs = musicInt(
        musicMap(info['play_song_detail'])['position'] ?? info['position'],
      ),
      durationMs = musicInt(
        musicMap(info['play_song_detail'])['duration'] ?? info['duration'],
      ),
      audioId = _audioId(info);

  final int? status, volume, positionMs, durationMs;
  final String? audioId;
  bool get playing => status == 1;
  bool get paused => status == 2;
  bool get stopped => status == 0;

  static String? _audioId(Map<String, Object?> info) {
    final detail = musicMap(info['play_song_detail']);
    return [
      detail['audio_id'],
      detail['global_id'],
      detail['id'],
      info['audio_id'],
    ].map(_id).nonNulls.firstOrNull;
  }

  static String? _id(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
