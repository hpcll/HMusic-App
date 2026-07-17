import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/hmusic_track.dart';
import '../network/api_failure.dart';
import '../providers/infrastructure_providers.dart';
import 'api_playback_repository.dart';
import 'local_volume_store.dart';
import 'models/hmusic_playback_state.dart' as server;
import 'playback_projection.dart';
import 'playback_repository.dart';
import 'shared_preferences_local_volume_store.dart';
import 'stream_url_rebaser.dart';

final Provider<LocalVolumeStore> localVolumeStoreProvider =
    Provider<LocalVolumeStore>((ref) => SharedPreferencesLocalVolumeStore());

// 音源装载最终失败（重解析自救也没救回来）：携带用户可读文案冒泡，前台点播
// VM 的兜底 catch 直接把它拼进错误提示，不再露 just_audio 的原始错误码。
class PlaybackLoadException implements Exception {
  const PlaybackLoadException(this.trackTitle);

  final String trackTitle;

  @override
  String toString() => '「$trackTitle」音源加载失败，可能是直链已失效';
}

final FutureProvider<HMusicAudioHandler> hmusicAudioHandlerProvider =
    FutureProvider<HMusicAudioHandler>((ref) async {
      final handler = await AudioService.init(
        builder: () => HMusicAudioHandler(
          playbackRepository: ref.watch(playbackRepositoryProvider),
          streamUrlRebaser: StreamUrlRebaser(
            serverConfigStore: ref.watch(serverConfigStoreProvider),
          ),
          localVolumeStore: ref.watch(localVolumeStoreProvider),
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.hupc.hmusic.playback',
          androidNotificationChannelName: 'HMusic 播放',
          androidNotificationOngoing: true,
        ),
      );
      ref.onDispose(() => unawaited(handler.disposeHandler()));
      return handler;
    });

class HMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  HMusicAudioHandler({
    required PlaybackRepository playbackRepository,
    required StreamUrlRebaser streamUrlRebaser,
    required LocalVolumeStore localVolumeStore,
    AudioPlayer? player,
  }) : _repository = playbackRepository,
       _streamUrlRebaser = streamUrlRebaser,
       _localVolumeStore = localVolumeStore,
       _player = player ?? AudioPlayer() {
    _playerStateSubscription = _player.playerStateStream.listen(_onPlayerState);
    _playbackEventSubscription = _player.playbackEventStream.listen(
      (_) => _publishPlaybackState(),
    );
  }

  static const String localDeviceId = 'local-browser';

  final PlaybackRepository _repository;
  final StreamUrlRebaser _streamUrlRebaser;
  final LocalVolumeStore _localVolumeStore;
  final AudioPlayer _player;

  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<PlaybackEvent> _playbackEventSubscription;
  server.HMusicPlaybackState? _serverState;
  final StreamController<server.HMusicPlaybackState> _serverStateController =
      StreamController<server.HMusicPlaybackState>.broadcast();
  // 播放链路自身的失败通知：自动切歌撞死链这类 fire-and-forget 路径没有
  // 前台点播 VM 兜着，壳层订阅本流统一弹 toast。只发用户可读文案。
  final StreamController<String> _noticeController =
      StreamController<String>.broadcast();
  Uri? _loadedUri;
  Timer? _reportTimer;
  bool _reportInFlight = false;
  bool _handlingEnded = false;
  // 直链失效恢复去抖（docs/08 §7）：同一曲目 60s 内最多自动重解析一次，
  // 防坏源「解析成功→加载失败→再解析」死循环。
  String? _recoverKey;
  DateTime? _recoverAt;

  // 服务端权威播放状态（封面/曲目/队列指针/模式/设备）。播放页订阅它渲染，
  // 本机实时进度另取 just_audio 的 position，不用这里每 3 秒的回写值反算。
  Stream<server.HMusicPlaybackState> get serverStateStream =>
      _serverStateController.stream;

  server.HMusicPlaybackState? get serverState => _serverState;

  // 播放失败等用户必须知道的事：壳层 ref.listen 后统一弹错误 toast。
  Stream<String> get playbackNoticeStream => _noticeController.stream;

  // 首次订阅播放状态时的兜底：本机还没有任何服务端状态缓存（冷启动、从未播放）
  // 就拉一次 /playback/state，否则 serverStateStream 永不产出，播放页无限转圈。
  // 只取状态用于展示，不 autoplay、不加载音频。
  Future<void> ensureServerState() async {
    if (_serverState != null) return;
    _setServerState(await _repository.getState());
  }

  AudioPlayer get player => _player;

  Future<void> playTrack(HMusicTrack track, {int? queueIndex}) async {
    final state = await _repository.playTrack(track, queueIndex: queueIndex);
    await _applyServerState(state, autoplay: true);
  }

  // 歌单/整榜等组合播放命令的权威响应直接落地：目标是本机设备时立即装载
  // 出声，不等前台轮询；目标是远端设备时按既有逻辑停本机。只该在服务端刚
  // 执行完「开播」类命令后调用，所以 autoplay 恒真，与 playTrack 一致。
  Future<void> applyRemotePlayback(server.HMusicPlaybackState state) {
    return _applyServerState(state, autoplay: true);
  }

  @override
  Future<void> play() async {
    final state = await _repository.resume();
    final streamUrl = state.streamUrl;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      await _applyServerState(state, autoplay: true);
      return;
    }
    final track = state.track;
    if (track != null &&
        state.deviceId == localDeviceId &&
        _loadedUri == null) {
      // 会话有当前曲但响应无直链、本机也从没装载过（队列播完直链被清、冷启动
      // 接续旧会话等）：bare play() 只会空转——UI 翻成「播放中」却永远无声。
      // 原曲重解析装载出声，救不动按装载失败如实收场。
      _setServerState(state);
      await _recoverOrFail(track, state);
      return;
    }
    await _player.play();
    _startReporting();
    _publishPlaybackState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _setServerState(await _repository.pause());
    await _reportCurrentState();
    _publishPlaybackState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _setServerState(await _repository.seek(position.inMilliseconds));
    _publishPlaybackState();
  }

  @override
  Future<void> skipToNext() async {
    await _applyServerState(await _repository.next(), autoplay: true);
  }

  @override
  Future<void> skipToPrevious() async {
    await _applyServerState(await _repository.previous(), autoplay: true);
  }

  Future<void> setPlayMode(server.PlayMode mode) async {
    _setServerState(await _repository.setPlayMode(mode));
    _publishPlaybackState();
  }

  @override
  Future<void> stop() async {
    _reportTimer?.cancel();
    _reportTimer = null;
    await _player.stop();
    _setServerState(await _repository.stop());
    _loadedUri = null;
    await super.stop();
    _publishPlaybackState();
  }

  Future<void> setLocalVolume(double volume) async {
    final normalized = volume.clamp(0, 1).toDouble();
    await _player.setVolume(normalized);
    await _localVolumeStore.write(normalized);
  }

  Future<void> disposeHandler() async {
    _reportTimer?.cancel();
    await _playerStateSubscription.cancel();
    await _playbackEventSubscription.cancel();
    await _serverStateController.close();
    await _noticeController.close();
    await _player.dispose();
  }

  void _setServerState(server.HMusicPlaybackState state) {
    _serverState = state;
    if (!_serverStateController.isClosed) _serverStateController.add(state);
  }

  Future<void> _applyServerState(
    server.HMusicPlaybackState state, {
    required bool autoplay,
  }) async {
    _setServerState(state);
    final track = state.track;
    if (state.deviceId != localDeviceId || track == null) {
      await _player.stop();
      _loadedUri = null;
      _publishPlaybackState();
      return;
    }

    final streamUrl = state.streamUrl;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final uri = await _streamUrlRebaser.rebase(streamUrl);
      if (_loadedUri != uri) {
        try {
          // 坏直链可能既不成功也不报错（上游黑洞），必须限时：否则播放链路
          // 无声卡死在 loading，界面还顶着服务端的「正在播放」。
          await _loadTrack(
            uri,
            track,
            state.positionMs,
          ).timeout(const Duration(seconds: 20));
        } on PlayerException {
          // 直链失效恢复（docs/08 §7）：服务端快照/缓存里的 streamUrl 可能已过
          // CDN 时效（历史记录直接点播放是典型场景，AVFoundation 报 -11849）。
          await _recoverOrFail(track, state);
          return; // 恢复路径已递归走完 _applyServerState（含 autoplay）。
        } on TimeoutException {
          await _recoverOrFail(track, state);
          return;
        }
      }
    }
    if (autoplay && _loadedUri != null) await _player.play();
    _startReporting();
    _publishPlaybackState();
  }

  // 装载失败的统一出口：重解析自救（60s 去抖，docs/08 §7），救回来即续播；
  // 救不回来必须如实收场，禁止停留在「正在播放」假象——
  //   1. 暂停本机 player：上一首残留的 playing 真值会让周期回写继续向服务端
  //      谎报 playing，语义状态永远回不到真实；
  //   2. 回写 paused（进度停在目标点，60s 后重试可从这续）；
  //   3. 全局通知流报错（自动切歌等无人捕获的路径全靠它出声）；
  //   4. 抛可读异常给前台点播 VM 的错误提示。
  Future<void> _recoverOrFail(
    HMusicTrack track,
    server.HMusicPlaybackState state,
  ) async {
    if (await _tryRecoverStaleUrl(track, state)) return;
    final failure = PlaybackLoadException(track.title);
    await _player.pause();
    if (!_noticeController.isClosed) _noticeController.add(failure.toString());
    try {
      _setServerState(
        await _repository.reportLocal(
          state: 'paused',
          positionMs: state.positionMs,
        ),
      );
    } on ApiFailure {
      // 回写失败不追加处理：player 已暂停，下一轮周期回写自然把 paused 带回去。
    }
    _publishPlaybackState();
    throw failure;
  }

  // 原曲重解析续播。成功返回 true（新状态已应用），不可救返回 false。
  Future<bool> _tryRecoverStaleUrl(
    HMusicTrack track,
    server.HMusicPlaybackState state,
  ) async {
    final key = '${track.source}:${track.sourceTrackId}';
    final now = DateTime.now();
    if (_recoverKey == key &&
        _recoverAt != null &&
        now.difference(_recoverAt!) < const Duration(seconds: 60)) {
      return false;
    }
    _recoverKey = key;
    _recoverAt = now;
    // 剥掉 track 里烤存的旧直链再发：服务端 resolveTrack 见 track.url 非空会
    // 短路原样返回（那是给手动直链曲目的通道），带着过期 url 去重解析等于
    // 让服务端把死链再发一遍。去掉 url 才走真正的插件解析。
    final resolvable = HMusicTrack(
      id: track.id,
      source: track.source,
      sourceTrackId: track.sourceTrackId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationMs: track.durationMs,
      coverUrl: track.coverUrl,
      qualities: track.qualities,
      raw: track.raw, // 插件解析要用（songmid 等平台参数）。
    );
    final server.HMusicPlaybackState fresh;
    try {
      fresh = await _repository.playTrack(
        resolvable,
        queueIndex: state.queueIndex >= 0 ? state.queueIndex : null,
        positionMs: state.positionMs,
      );
    } on ApiFailure {
      return false; // 重解析也失败（音源死了）：交回原始加载错误。
    }
    await _applyServerState(fresh, autoplay: true);
    return true;
  }

  Future<void> _loadTrack(Uri uri, HMusicTrack track, int positionMs) async {
    final item = mediaItemForTrack(track);
    mediaItem.add(item);
    await _player.setVolume(await _localVolumeStore.read());
    await _player.setAudioSource(
      AudioSource.uri(uri, tag: item),
      initialPosition: Duration(milliseconds: positionMs),
    );
    _loadedUri = uri;
  }

  void _startReporting() {
    _reportTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_reportCurrentState()),
    );
  }

  Future<void> _reportCurrentState() async {
    if (_reportInFlight || _serverState?.deviceId != localDeviceId) return;
    _reportInFlight = true;
    try {
      _setServerState(
        await _repository.reportLocal(
          state: _player.playing ? 'playing' : 'paused',
          positionMs: _player.position.inMilliseconds,
          durationMs: _player.duration?.inMilliseconds,
        ),
      );
    } on ApiFailure {
      // 周期回写失败不停止本机音频（docs/08 §6）：退避到下一周期。
      // 401 由 ApiClient→SessionController 统一处理，这里吞掉避免冒泡打断播放器。
    } finally {
      _reportInFlight = false;
    }
  }

  void _onPlayerState(PlayerState state) {
    _publishPlaybackState();
    if (state.processingState == ProcessingState.completed && !_handlingEnded) {
      unawaited(_handleEnded());
    }
  }

  Future<void> _handleEnded() async {
    _handlingEnded = true;
    try {
      final next = await _repository.reportLocal(ended: true);
      await _applyServerState(
        next,
        autoplay: next.state == server.PlaybackStatus.playing,
      );
    } catch (_) {
      // ended 是非幂等推进命令只发一次（docs/08 §6），失败改按 state 归并。
      // 归并自身也可能失败（断网/凭据暂不可用）——_handleEnded 是
      // fire-and-forget，异常必须就地消化，否则成未捕获错误且队列卡死。
      try {
        final latest = await _repository.getState();
        if (latest.track?.id != _serverState?.track?.id) {
          await _applyServerState(
            latest,
            autoplay: latest.state == server.PlaybackStatus.playing,
          );
        }
      } catch (_) {
        // 保持现状：等周期上报恢复或用户手动下一首时自然归并。
      }
    } finally {
      _handlingEnded = false;
    }
  }

  void _publishPlaybackState() {
    playbackState.add(
      playbackStateProjection(player: _player, serverState: _serverState),
    );
  }
}
