import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/local_volume_store.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/playback_repository.dart';
import 'package:hmusic/core/audio/stream_url_rebaser.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

// 遥控模式（播放目标=音箱）回归：双端同响的三条根因全部锁死——
// 1) resume/点歌响应目标为远端时，本机 player 只许 stop、绝不拉起；
// 2) 点歌缺省不带 deviceId（跟随服务端所选默认设备），不再劫持回本机；
// 3) 远端态启动 5s 状态轮询（服务端音箱回读与自动连播靠被读驱动），回本机即停。
class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeVolumeStore implements LocalVolumeStore {
  @override
  Future<double> read() async => 1.0;

  @override
  Future<void> write(double volume) async {}
}

class _FakeServerConfigStore implements ServerConfigStore {
  @override
  Future<Uri?> read() async => Uri.parse('http://192.168.2.52:8090');

  @override
  Future<void> write(Uri serverBase) async {}

  @override
  Future<void> clear() async {}
}

const HMusicTrack _track = HMusicTrack(
  id: 'tx:1',
  source: 'tx',
  sourceTrackId: '1',
  title: '晴天',
  artist: '周杰伦',
);

HMusicPlaybackState _state({
  String? deviceId = 'speaker-1',
  PlaybackStatus state = PlaybackStatus.playing,
  int volume = 60,
  String? streamUrl,
  int updatedAt = 0,
}) => HMusicPlaybackState(
  sessionId: 'default',
  state: state,
  positionMs: 5000,
  durationMs: 231000,
  volume: volume,
  playMode: PlayMode.listLoop,
  queueIndex: 0,
  queueLength: 1,
  seekEnabled: true,
  updatedAt: updatedAt,
  deviceId: deviceId,
  deviceName: deviceId == null
      ? null
      : deviceId == HMusicPlaybackState.localDeviceId
      ? '本机'
      : '客厅音箱',
  streamUrl: streamUrl,
  track: _track,
);

class _FakeRepository implements PlaybackRepository {
  _FakeRepository({
    HMusicPlaybackState? resumeState,
    HMusicPlaybackState? playTrackState,
    HMusicPlaybackState? seekState,
    HMusicPlaybackState? volumeState,
    HMusicPlaybackState? getStateResult,
    this.reportLocalState,
  }) : resumeState = resumeState ?? _state(),
       playTrackState = playTrackState ?? _state(),
       seekState = seekState ?? _state(),
       volumeState = volumeState ?? _state(),
       getStateResult = getStateResult ?? _state();

  final HMusicPlaybackState resumeState;
  final HMusicPlaybackState playTrackState;
  final HMusicPlaybackState seekState;
  final HMusicPlaybackState volumeState;
  final HMusicPlaybackState? reportLocalState;
  HMusicPlaybackState getStateResult;

  int getStateCalls = 0;
  final List<String?> playTrackDeviceIds = <String?>[];
  final List<int> setVolumeCalls = <int>[];
  int seekCalls = 0;

  @override
  Future<HMusicPlaybackState> getState() async {
    getStateCalls += 1;
    return getStateResult;
  }

  @override
  Future<HMusicPlaybackState> resume() async => resumeState;

  @override
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
    String? deviceId,
  }) async {
    playTrackDeviceIds.add(deviceId);
    return playTrackState;
  }

  @override
  Future<HMusicPlaybackState> seek(int positionMs) async {
    seekCalls += 1;
    return seekState;
  }

  @override
  Future<HMusicPlaybackState> setVolume(int volume) async {
    setVolumeCalls.add(volume);
    return volumeState;
  }

  @override
  Future<HMusicPlaybackState> pause() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> next() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> previous() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> stop() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> setPlayMode(PlayMode mode) =>
      throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) async => reportLocalState ?? (throw UnimplementedError());
}

_MockAudioPlayer _player() {
  final player = _MockAudioPlayer();
  when(
    () => player.playerStateStream,
  ).thenAnswer((_) => const Stream<PlayerState>.empty());
  when(
    () => player.playbackEventStream,
  ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
  when(() => player.play()).thenAnswer((_) async {});
  when(() => player.pause()).thenAnswer((_) async {});
  when(() => player.stop()).thenAnswer((_) async {});
  when(() => player.seek(any())).thenAnswer((_) async {});
  when(() => player.processingState).thenReturn(ProcessingState.idle);
  when(() => player.playing).thenReturn(false);
  when(() => player.position).thenReturn(Duration.zero);
  when(() => player.bufferedPosition).thenReturn(Duration.zero);
  when(() => player.speed).thenReturn(1.0);
  when(() => player.duration).thenReturn(const Duration(milliseconds: 231000));
  when(() => player.setVolume(any())).thenAnswer((_) async {});
  when(
    () => player.setAudioSource(
      any(),
      initialPosition: any(named: 'initialPosition'),
    ),
  ).thenAnswer((_) async => null);
  when(() => player.dispose()).thenAnswer((_) async {});
  return player;
}

HMusicAudioHandler _handler(_FakeRepository repository, AudioPlayer player) {
  return HMusicAudioHandler(
    playbackRepository: repository,
    streamUrlRebaser: StreamUrlRebaser(
      serverConfigStore: _FakeServerConfigStore(),
    ),
    localVolumeStore: _FakeVolumeStore(),
    player: player,
  );
}

class _FakeAudioSource extends Fake implements AudioSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(_FakeAudioSource());
  });

  test('目标为音箱的 resume：本机 player 只 stop 不拉起，状态照常落地', () async {
    final repository = _FakeRepository(resumeState: _state());
    final player = _player();
    final handler = _handler(repository, player);

    await handler.play();

    // 双端同响根因之一：旧实现漏到 _player.play() 把本机也拉响。
    verifyNever(() => player.play());
    verify(() => player.stop()).called(1);
    expect(handler.serverState?.deviceId, 'speaker-1');
    await handler.disposeHandler();
  });

  test('点歌缺省不带 deviceId；响应为音箱时本机停、mediaItem 显示音箱曲目', () async {
    final repository = _FakeRepository(playTrackState: _state());
    final player = _player();
    final handler = _handler(repository, player);

    await handler.playTrack(_track);

    // 双端同响根因之二：旧实现硬编码 local-browser，把已选音箱劫持回手机。
    expect(repository.playTrackDeviceIds.single, isNull);
    verifyNever(() => player.play());
    verify(() => player.stop()).called(1);
    // mini player/锁屏照常显示音箱在播曲目（媒体键仍走 handler → 服务端）。
    expect(handler.mediaItem.valueOrNull?.title, '晴天');
    await handler.disposeHandler();
  });

  test('目标为音箱的 seek：只发服务端，不碰本机 player', () async {
    final repository = _FakeRepository(resumeState: _state());
    final player = _player();
    final handler = _handler(repository, player);
    await handler.play(); // 进入远端态。

    await handler.seek(const Duration(seconds: 30));

    expect(repository.seekCalls, 1);
    verifyNever(() => player.seek(any()));
    await handler.disposeHandler();
  });

  test('setDeviceVolume 走服务端 0-100 通道并落地权威状态', () async {
    final repository = _FakeRepository(volumeState: _state(volume: 80));
    final player = _player();
    final handler = _handler(repository, player);

    await handler.setDeviceVolume(80);

    expect(repository.setVolumeCalls.single, 80);
    expect(handler.serverState?.volume, 80);
    // 音箱音量绝不写本机 player/本地偏好（docs/12 §4 分流铁律）。
    verifyNever(() => player.setVolume(any()));
    await handler.disposeHandler();
  });

  test('远端态启动 5s 状态轮询，目标回本机即停', () {
    fakeAsync((async) {
      final repository = _FakeRepository(resumeState: _state());
      final player = _player();
      final handler = _handler(repository, player);

      unawaited(handler.play());
      async.flushMicrotasks();
      expect(repository.getStateCalls, 0);

      // 远端态：每 5s 拉一次权威状态（驱动服务端音箱回读与自动连播）。
      async.elapse(const Duration(seconds: 5));
      expect(repository.getStateCalls, 1);
      async.elapse(const Duration(seconds: 5));
      expect(repository.getStateCalls, 2);

      // 服务端目标切回本机（如 web 端接管）：轮询停止，不再打扰。
      repository.getStateResult = _state(
        deviceId: HMusicPlaybackState.localDeviceId,
      );
      async.elapse(const Duration(seconds: 5));
      expect(repository.getStateCalls, 3);
      async.elapse(const Duration(seconds: 30));
      expect(repository.getStateCalls, 3);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('轮询到音箱换曲：mediaItem 跟进新曲目', () {
    fakeAsync((async) {
      final repository = _FakeRepository(resumeState: _state());
      final player = _player();
      final handler = _handler(repository, player);
      unawaited(handler.play());
      async.flushMicrotasks();

      repository.getStateResult = HMusicPlaybackState(
        sessionId: 'default',
        state: PlaybackStatus.playing,
        positionMs: 0,
        durationMs: 200000,
        volume: 60,
        playMode: PlayMode.listLoop,
        queueIndex: 1,
        queueLength: 2,
        seekEnabled: true,
        updatedAt: 0,
        deviceId: 'speaker-1',
        track: const HMusicTrack(
          id: 'tx:2',
          source: 'tx',
          sourceTrackId: '2',
          title: '七里香',
          artist: '周杰伦',
        ),
      );
      async.elapse(const Duration(seconds: 5));

      expect(handler.mediaItem.valueOrNull?.title, '七里香');
      expect(handler.serverState?.queueIndex, 1);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('本机在播时目标被其它端切走：周期回写响应立即停本机', () {
    fakeAsync((async) {
      final repository = _FakeRepository(
        resumeState: _state(
          deviceId: HMusicPlaybackState.localDeviceId,
          streamUrl: 'http://old.host/api/v1/proxy/audio?u=a',
        ),
        // Web 端把目标切到音箱后，回写响应的 deviceId 已是音箱。
        reportLocalState: _state(),
      );
      final player = _player();
      final handler = _handler(repository, player);

      unawaited(handler.play());
      async.flushMicrotasks();
      verify(() => player.play()).called(1);

      // 3s 周期回写返回远端目标 → 立即停本机（双端同响的最后一条复现路径）。
      async.elapse(const Duration(seconds: 3));
      verify(() => player.stop()).called(1);
      expect(handler.serverState?.deviceId, 'speaker-1');

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('冷状态无 deviceId：不启动空轮询', () {
    fakeAsync((async) {
      final repository = _FakeRepository(
        getStateResult: _state(deviceId: null),
      );
      final player = _player();
      final handler = _handler(repository, player);

      unawaited(handler.ensureServerState());
      async.flushMicrotasks();
      expect(repository.getStateCalls, 1);

      // 全新 Server 从未播过：没有远端目标，30s 内不该有任何轮询。
      async.elapse(const Duration(seconds: 30));
      expect(repository.getStateCalls, 1);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('轮询快照比当前状态旧（updatedAt 更小）：丢弃不闪回', () {
    fakeAsync((async) {
      final repository = _FakeRepository(resumeState: _state(updatedAt: 2000));
      final player = _player();
      final handler = _handler(repository, player);
      unawaited(handler.play());
      async.flushMicrotasks();

      // 命令响应（updatedAt=2000）已落地，迟到的旧快照（1000）必须丢弃。
      repository.getStateResult = _state(updatedAt: 1000, volume: 99);
      async.elapse(const Duration(seconds: 5));
      expect(handler.serverState?.volume, 60);

      // 更新的快照（3000）正常落地。
      repository.getStateResult = _state(updatedAt: 3000, volume: 99);
      async.elapse(const Duration(seconds: 5));
      expect(handler.serverState?.volume, 99);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('冷启动接续音箱播放：ensureServerState 立即跟进 mediaItem', () async {
    final repository = _FakeRepository(getStateResult: _state());
    final player = _player();
    final handler = _handler(repository, player);

    await handler.ensureServerState();

    // mini player 不等首轮轮询（否则冷启动最多晚 5s 才出现）。
    expect(handler.mediaItem.valueOrNull?.title, '晴天');
    await handler.disposeHandler();
  });
}
