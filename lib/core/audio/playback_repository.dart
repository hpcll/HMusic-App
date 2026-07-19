import '../models/hmusic_track.dart';
import 'models/hmusic_playback_state.dart';

abstract interface class PlaybackRepository {
  Future<HMusicPlaybackState> getState();

  // positionMs：直链失效恢复时带上原进度续播（docs/08 §7），服务端缺省从 0 开播。
  // deviceId：缺省不发，服务端 resolve 用户选定的默认设备（点歌跟随所选设备，
  // 音箱选中时不劫持回本机）；直链恢复等明确本机场景才显式传 local。
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
    String? deviceId,
  });

  Future<HMusicPlaybackState> pause();

  Future<HMusicPlaybackState> resume();

  Future<HMusicPlaybackState> next();

  Future<HMusicPlaybackState> previous();

  Future<HMusicPlaybackState> stop();

  Future<HMusicPlaybackState> seek(int positionMs);

  Future<HMusicPlaybackState> setPlayMode(PlayMode mode);

  // 播放目标音量 0-100：远端设备（音箱）由服务端下发指令；本机音量不走这里
  //（just_audio + 本地偏好，见 docs/12 §4）。
  Future<HMusicPlaybackState> setVolume(int volume);

  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  });
}
