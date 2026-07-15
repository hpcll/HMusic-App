import '../models/hmusic_track.dart';
import 'models/hmusic_playback_state.dart';

abstract interface class PlaybackRepository {
  Future<HMusicPlaybackState> getState();

  Future<HMusicPlaybackState> playTrack(HMusicTrack track, {int? queueIndex});

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
