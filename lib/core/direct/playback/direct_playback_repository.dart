import 'dart:math';

import '../../async/serial_executor.dart';
import '../../audio/models/hmusic_playback_state.dart';
import '../../audio/models/playback_state_update.dart';
import '../../audio/playback_repository.dart';
import '../../models/hmusic_track.dart';
import '../../network/api_failure.dart';
import '../../queue/direct_queue_repository.dart';
import '../direct_device_registry.dart';
import '../mi_mina_client.dart';
import '../music/direct_audio_proxy.dart';
import '../music/direct_track_resolver.dart';
import '../music/platform_track_mapper.dart';
import '../storage/direct_local_store.dart';
import 'mi_speaker_commands.dart';
import 'mi_speaker_playback.dart';
import 'mi_speaker_status.dart';

part 'direct_playback_commands.dart';
part 'direct_playback_storage.dart';
part 'direct_playback_sync.dart';

/// 直连的队列/播放事实所有者；UI、锁屏、音箱轮询共享这一条串行命令链。
class DirectPlaybackRepository implements PlaybackRepository {
  DirectPlaybackRepository({
    required DirectLocalStore store,
    required DirectQueueRepository queue,
    required DirectDeviceRegistry devices,
    required DirectTrackResolver resolver,
    required DirectAudioProxy proxy,
    required MiMinaClient client,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _store = store,
       _queue = queue,
       _devices = devices,
       _resolver = resolver,
       _proxy = proxy,
       _client = client,
       _now = now ?? DateTime.now,
       _delay = delay;

  final DirectLocalStore _store;
  final DirectQueueRepository _queue;
  final DirectDeviceRegistry _devices;
  final DirectTrackResolver _resolver;
  final DirectAudioProxy _proxy;
  final MiMinaClient _client;
  final DateTime Function() _now;
  final Future<void> Function(Duration)? _delay;
  final SerialExecutor _serial = SerialExecutor();
  late MiSpeakerCommands _commands;
  late MiSpeakerPlayback _speaker;
  HMusicPlaybackState? _state;
  Uri? _remoteStream;
  DateTime? _remoteResolvedAt;
  DateTime? _deadline;
  bool _foreground = true;
  int _lifecycleGeneration = 0;
  bool get foreground => _foreground;
  set foreground(bool value) {
    if (_foreground != value) _lifecycleGeneration++;
    if (!_foreground && value && _state?.isLocalDevice == false) {
      _needsVerification = true;
    }
    _foreground = value;
  }

  bool _observedRemotePlaying = false;
  bool _ownsRemote = false;
  bool _needsVerification = false;
  bool _historyRecorded = true;
  String? _remoteAudioId;
  DateTime? _commandProtectedUntil;
  int? _lastRemotePosition;
  DateTime? _lastRemoteProgressAt;

  Future<T> _run<T>(Future<T> Function() action) => _serial.run(() async {
    await _restore();
    return action();
  });

  @override
  Future<HMusicPlaybackState> getState() => _run(_synchronize);

  @override
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
    String? deviceId,
  }) => _run(
    () => _play(
      track,
      queueIndex: queueIndex,
      positionMs: positionMs ?? 0,
      deviceId: deviceId,
    ),
  );

  Future<HMusicPlaybackState> playQueue(
    List<HMusicTrack> tracks, {
    int startIndex = 0,
    bool Function()? isCurrent,
    void Function(int revision)? onQueueReplaced,
  }) => _run(() async {
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '歌单为空或播放位置已失效',
      );
    }
    return _play(
      tracks[startIndex],
      queueIndex: startIndex,
      replacement: tracks,
      isCurrent: isCurrent,
      onQueueReplaced: onQueueReplaced,
    );
  });

  Future<HMusicPlaybackState> selectDevice(String id) => _run(() async {
    final target = await _devices.device(id);
    if (_state!.deviceId == id) return _state!;
    await _stopRemote();
    _queue.cancelPendingAppends();
    await _devices.select(id);
    _deadline = null;
    _remoteStream = null;
    _remoteResolvedAt = null;
    _ownsRemote = false;
    _remoteAudioId = null;
    return _commit(
      _state!.update(
        deviceId: id,
        deviceName: target?.name ?? '本机播放',
        status: _state!.track == null
            ? PlaybackStatus.idle
            : PlaybackStatus.paused,
        seekEnabled: target?.profile.supportsSeek ?? true,
        clearStream: true,
      ),
    );
  });

  @override
  Future<HMusicPlaybackState> pause() => _run(_pause);
  @override
  Future<HMusicPlaybackState> resume() => _run(_resume);
  @override
  Future<HMusicPlaybackState> next() => _run(() => _advance());
  @override
  Future<HMusicPlaybackState> previous() =>
      _run(() => _advance(previous: true));
  @override
  Future<HMusicPlaybackState> stop() => _run(_stop);
  @override
  Future<HMusicPlaybackState> seek(int positionMs) =>
      _run(() => _seek(positionMs));

  @override
  Future<HMusicPlaybackState> setPlayMode(PlayMode mode) => _run(() async {
    final queue = await _queue.setPlayMode(mode);
    return _commit(_state!.update(playMode: queue.playMode));
  });

  @override
  Future<HMusicPlaybackState> setVolume(int volume) => _run(() async {
    final state = _state!;
    final device = await _devices.device(state.deviceId!);
    if (device == null) return state;
    final actual = await _commands.volume(
      await _devices.account.session(),
      device,
      volume,
    );
    return _commit(state.update(volume: actual ?? state.volume));
  });

  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) => _run(() async {
    if (!_state!.isLocalDevice) return _state!;
    if (ended) {
      if (_state!.state != PlaybackStatus.playing) return _state!;
      return _advance(automatic: true);
    }
    if (state == 'playing') await _recordHistory();
    return _commit(
      _state!.update(
        status: switch (state) {
          'playing' => PlaybackStatus.playing,
          'paused' => PlaybackStatus.paused,
          _ => _state!.state,
        },
        positionMs: positionMs?.clamp(0, 1 << 52),
        durationMs: durationMs,
      ),
    );
  });

  Future<void> close() => _serial.run(() async {
    _queue.cancelPendingAppends();
    _deadline = null;
    _remoteStream = null;
    _remoteResolvedAt = null;
    _state = null;
    _ownsRemote = false;
    _needsVerification = false;
    _remoteAudioId = null;
    _commandProtectedUntil = null;
    _lastRemotePosition = null;
    _lastRemoteProgressAt = null;
    await _proxy.close();
  });
}
