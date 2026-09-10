import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../async/serial_executor.dart';
import '../models/hmusic_track.dart';
import '../network/api_failure.dart';
import '../platform/client_playback_capabilities.dart';
import '../playback/backend_request.dart';
import '../playback/playback_mode_controller.dart';
import '../providers/infrastructure_providers.dart';
import 'api_playback_repository.dart';
import 'local_volume_store.dart';
import 'mode_stream_url_rebaser.dart';
import 'models/hmusic_playback_state.dart' as server;
import 'playback_projection.dart';
import 'playback_repository.dart';
import 'remote_state_poller.dart';
import 'shared_preferences_local_volume_store.dart';
import 'stream_url_rebaser.dart';

part 'hmusic_audio_commands.dart';
part 'hmusic_audio_initialization.dart';
part 'hmusic_audio_loading.dart';
part 'hmusic_audio_reporting.dart';
part 'hmusic_audio_session.dart';
part 'hmusic_playback_state_sync.dart';

class HMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  HMusicAudioHandler({
    required PlaybackRepository playbackRepository,
    required StreamUrlRebaser streamUrlRebaser,
    required LocalVolumeStore localVolumeStore,
    ClientPlaybackCapabilities capabilities = const ClientPlaybackCapabilities(
      supportsLocalPlayback: true,
    ),
    AudioPlayer? player,
    int Function()? backendGeneration,
  }) : _repository = playbackRepository,
       _streamUrlRebaser = streamUrlRebaser,
       _localVolumeStore = localVolumeStore,
       _capabilities = capabilities,
       _backendGeneration = backendGeneration,
       _player = player ?? AudioPlayer() {
    _remotePoller = RemoteStatePoller(
      repository: playbackRepository,
      onState: _onRemoteState,
    );
    _playerStateSubscription = _player.playerStateStream.listen(_onPlayerState);
    _playbackEventSubscription = _player.playbackEventStream.listen(
      (_) => _publishPlaybackState(),
    );
  }

  static const String localDeviceId = server.HMusicPlaybackState.localDeviceId;

  final PlaybackRepository _repository;
  final StreamUrlRebaser _streamUrlRebaser;
  final LocalVolumeStore _localVolumeStore;
  final AudioPlayer _player;
  final ClientPlaybackCapabilities _capabilities;
  late final RemoteStatePoller _remotePoller;

  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<PlaybackEvent> _playbackEventSubscription;
  server.HMusicPlaybackState? _serverState;
  // 遥控进度外推器：远端权威进度 5s 一跳，落地即校准、读取时本地预测。
  final RemotePositionProjector _remoteProjector = RemotePositionProjector();
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
  bool _transportBusy = false;
  final SerialExecutor _commands = SerialExecutor();
  final int Function()? _backendGeneration;
  int _backendEpoch = 0;
  int _loadGeneration = 0;
  int _completedGeneration = -1;
  String? _loadedTrackId;
  // 直链失效恢复去抖（docs/08 §7）：同一曲目 60s 内最多自动重解析一次，
  // 防坏源「解析成功→加载失败→再解析」死循环。
  String? _recoverKey;
  DateTime? _recoverAt;

  // 服务端权威播放状态（封面/曲目/队列指针/模式/设备）。播放页订阅它渲染，
  // 本机实时进度另取 just_audio 的 position，不用这里每 3 秒的回写值反算。
  Stream<server.HMusicPlaybackState> get serverStateStream =>
      _serverStateController.stream;

  server.HMusicPlaybackState? get serverState => _serverState;

  // 实时进度唯一出口（进度条/歌词染色都从这取，禁止各页自行分流）：
  // 本机取 just_audio 真值；远端取外推估算，不再随 5s 轮询按段步进。
  Duration get effectivePosition {
    final state = _serverState;
    if (state != null && !state.isLocalDevice) {
      return _remoteProjector.estimate(DateTime.now());
    }
    if (state != null &&
        (_loadedUri == null || !_capabilities.supportsLocalPlayback)) {
      return Duration(milliseconds: state.positionMs);
    }
    return _player.position;
  }

  // 播放失败等用户必须知道的事：壳层 ref.listen 后统一弹错误 toast。
  Stream<String> get playbackNoticeStream => _noticeController.stream;

  // 首次订阅播放状态时的兜底：本机还没有任何服务端状态缓存（冷启动、从未播放）
  // 就拉一次 /playback/state，否则 serverStateStream 永不产出，播放页无限转圈。
  // 只取状态用于展示，不 autoplay、不加载音频。
  Future<void> ensureServerState() => _commands.run(_ensureBackendState);

  Future<void> refreshPlaybackState() => _commands.run(() async {
    await _applyOrSet(await _repository.getState());
    _publishPlaybackState();
  });

  AudioPlayer get player => _player;

  Future<void> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    bool Function()? stillCurrent,
  }) => _runPlayback(() {
    if (stillCurrent != null && !stillCurrent()) throw BackendRequest.changed;
    return _playTrack(track, queueIndex);
  }, showLoading: true);

  // 歌单/整榜等组合播放命令的权威响应直接落地：目标是本机设备时立即装载
  // 出声，不等前台轮询；目标是远端设备时按既有逻辑停本机。autoplay 默认真
  //（播放命令场景），设备切换等纯状态同步场景传 false（只停旧设备、不开播）。
  Future<void> applyRemotePlayback(
    server.HMusicPlaybackState state, {
    bool autoplay = true,
  }) {
    return _runPlayback(
      () => _applyServerState(state, autoplay: autoplay),
      showLoading: autoplay,
    );
  }

  /// 整单播放和设备选择也与系统按钮、模式切换共用命令队列。
  Future<void> executePlayback(
    Future<server.HMusicPlaybackState> Function() action, {
    bool autoplay = true,
  }) => _runPlayback(() async {
    await _applyServerState(await action(), autoplay: autoplay);
  }, showLoading: autoplay);

  @override
  Future<void> play() => _runPlayback(_resumePlayback, showLoading: true);

  @override
  Future<void> pause() => _runPlayback(_pausePlayback);

  @override
  Future<void> seek(Duration position) =>
      _runPlayback(() => _seekPlayback(position));

  @override
  Future<void> skipToNext() => _runPlayback(() async {
    _requireSupportedTarget();
    await _applyServerState(await _repository.next(), autoplay: true);
  }, showLoading: true);

  @override
  Future<void> skipToPrevious() => _runPlayback(() async {
    _requireSupportedTarget();
    await _applyServerState(await _repository.previous(), autoplay: true);
  }, showLoading: true);

  Future<void> setPlayMode(server.PlayMode mode) => _runPlayback(() async {
    await _applyOrSet(await _repository.setPlayMode(mode));
    _publishPlaybackState();
  });

  @override
  Future<void> stop() => _runPlayback(() async {
    await _stopPlayback();
    await super.stop();
  });

  Future<void> setLocalVolume(double volume) async {
    _capabilities.requireLocalPlayback();
    final normalized = volume.clamp(0, 1).toDouble();
    await _player.setVolume(normalized);
    await _localVolumeStore.write(normalized);
  }

  // 远端设备（音箱）音量：0-100 经服务端 /playback/volume 下发设备指令。
  // 与 setLocalVolume 严格分流（docs/12 §4）：本机偏好绝不推给音箱。
  Future<void> setDeviceVolume(int volume) => _runPlayback(() async {
    await _applyOrSet(await _repository.setVolume(volume));
    _publishPlaybackState();
  });

  Future<void> transitionBackend(
    Future<void> Function() commit, {
    bool preservePosition = false,
  }) => _commands.run(() async {
    if (_serverState?.track != null) {
      if (preservePosition) {
        await _pauseForTransition();
      } else {
        await _stopPlayback();
      }
    }
    await _silence();
    await commit();
    _backendEpoch++;
    _clearSessionState();
  });

  /// 凭据已失效时仅清理本机，不再向无权限的旧后端发送 stop。
  Future<void> resetSession({bool Function()? stillInvalid}) =>
      _commands.run(() async {
        if (stillInvalid != null && !stillInvalid()) return;
        await _silence();
        _backendEpoch++;
        _clearSessionState();
      });

  // 前台播控失败的统一出口：播放页/mini player 的按钮回调都是 fire-and-forget，
  // PlayerViewModel 兜住 ApiFailure 后经此走全局通知流（壳层统一 toast）。
  void reportNotice(String message) {
    if (!_noticeController.isClosed) _noticeController.add(message);
  }

  void _requireSupportedTarget() {
    if (_serverState?.isLocalDevice ?? false) {
      _capabilities.requireLocalPlayback();
    }
  }

  Future<void> disposeHandler() async {
    _reportTimer?.cancel();
    _remotePoller.stop();
    await _playerStateSubscription.cancel();
    await _playbackEventSubscription.cancel();
    await _serverStateController.close();
    await _noticeController.close();
    await _player.dispose();
  }
}
