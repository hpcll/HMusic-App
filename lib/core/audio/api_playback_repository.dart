import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hmusic_track.dart';
import '../network/api_client.dart';
import '../providers/infrastructure_providers.dart';
import 'models/hmusic_playback_state.dart';
import 'playback_repository.dart';

final Provider<PlaybackRepository> playbackRepositoryProvider =
    Provider<PlaybackRepository>((ref) {
      return ApiPlaybackRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiPlaybackRepository implements PlaybackRepository {
  const ApiPlaybackRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<HMusicPlaybackState> getState() => _postOrGet('/playback/state');

  @override
  Future<HMusicPlaybackState> next() =>
      _postOrGet('/playback/next', post: true);

  @override
  Future<HMusicPlaybackState> pause() =>
      _postOrGet('/playback/pause', post: true);

  @override
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
    String? deviceId,
  }) {
    return _postOrGet(
      '/playback/play',
      post: true,
      body: <String, Object?>{
        'track': track.toJson(),
        // 缺省不发 deviceId：服务端 resolve 用户选定的默认设备。硬编码本机会把
        // 已选音箱的播放目标劫持回手机（音箱不停 + 本机开播 = 双端同响）。
        if (deviceId != null) 'deviceId': deviceId,
        // 队列点播必带：同名歌曲可能出现多次，靠它精确定位第几项。
        if (queueIndex != null) 'queueIndex': queueIndex,
        // 失效恢复续播用：服务端缺省 positionMs=0。
        if (positionMs != null) 'positionMs': positionMs,
      },
    );
  }

  @override
  Future<HMusicPlaybackState> previous() =>
      _postOrGet('/playback/previous', post: true);

  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) {
    return _postOrGet(
      '/playback/local-report',
      post: true,
      body: <String, Object?>{
        if (state != null) 'state': state,
        if (positionMs != null) 'positionMs': positionMs,
        if (durationMs != null) 'durationMs': durationMs,
        if (ended) 'ended': true,
      },
    );
  }

  @override
  Future<HMusicPlaybackState> resume() =>
      _postOrGet('/playback/resume', post: true);

  @override
  Future<HMusicPlaybackState> seek(int positionMs) {
    return _postOrGet(
      '/playback/seek',
      post: true,
      body: <String, Object?>{'positionMs': positionMs},
    );
  }

  @override
  Future<HMusicPlaybackState> setPlayMode(PlayMode mode) {
    return _postOrGet(
      '/playback/mode',
      post: true,
      body: <String, Object?>{'playMode': mode.wireName},
    );
  }

  @override
  Future<HMusicPlaybackState> setVolume(int volume) {
    return _postOrGet(
      '/playback/volume',
      post: true,
      body: <String, Object?>{'volume': volume.clamp(0, 100)},
    );
  }

  @override
  Future<HMusicPlaybackState> stop() =>
      _postOrGet('/playback/stop', post: true);

  Future<HMusicPlaybackState> _postOrGet(
    String path, {
    bool post = false,
    Map<String, Object?>? body,
  }) async {
    final payload = post
        ? await _apiClient.postMap(path, body: body)
        : await _apiClient.getMap(path);
    return HMusicPlaybackState.fromJson(payload);
  }
}
