import '../models/hmusic_track.dart';
import 'models/hmusic_playback_state.dart';

abstract interface class PlaybackRepository {
  Future<HMusicPlaybackState> getState();

  // positionMs：直链失效恢复时带上原进度续播（docs/08 §7），服务端缺省从 0 开播。
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
  });

  Future<HMusicPlaybackState> pause();

  Future<HMusicPlaybackState> resume();

  Future<HMusicPlaybackState> next();

  Future<HMusicPlaybackState> previous();

  Future<HMusicPlaybackState> stop();

  Future<HMusicPlaybackState> seek(int positionMs);

  Future<HMusicPlaybackState> setPlayMode(PlayMode mode);

  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  });
}
