import '../models/hmusic_track.dart';
import 'models/hmusic_playback_state.dart';
import 'playback_repository.dart';

/// Handler 的稳定依赖：切模式只替换目标仓库，不重复初始化系统 AudioService。
class RoutedPlaybackRepository implements PlaybackRepository {
  const RoutedPlaybackRepository(this._backend);
  final Future<PlaybackRepository> Function() _backend;
  @override
  Future<HMusicPlaybackState> getState() async => (await _backend()).getState();
  @override
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
    String? deviceId,
  }) async => (await _backend()).playTrack(
    track,
    queueIndex: queueIndex,
    positionMs: positionMs,
    deviceId: deviceId,
  );
  @override
  Future<HMusicPlaybackState> pause() async => (await _backend()).pause();
  @override
  Future<HMusicPlaybackState> resume() async => (await _backend()).resume();
  @override
  Future<HMusicPlaybackState> next() async => (await _backend()).next();
  @override
  Future<HMusicPlaybackState> previous() async => (await _backend()).previous();
  @override
  Future<HMusicPlaybackState> stop() async => (await _backend()).stop();
  @override
  Future<HMusicPlaybackState> seek(int positionMs) async =>
      (await _backend()).seek(positionMs);
  @override
  Future<HMusicPlaybackState> setPlayMode(PlayMode mode) async =>
      (await _backend()).setPlayMode(mode);
  @override
  Future<HMusicPlaybackState> setVolume(int volume) async =>
      (await _backend()).setVolume(volume);
  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) async => (await _backend()).reportLocal(
    state: state,
    positionMs: positionMs,
    durationMs: durationMs,
    ended: ended,
  );
}
