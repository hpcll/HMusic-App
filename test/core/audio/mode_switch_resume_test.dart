import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/models/playback_state_update.dart';
import 'package:hmusic/core/audio/playback_repository.dart';
import 'package:hmusic/core/audio/routed_playback_repository.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';

import '../playback/support/direct_fixture.dart';
import 'support/audio_fixture.dart';

class _Backend extends Fake implements PlaybackRepository {
  _Backend(String name, int position, {bool remote = false})
    : state = HMusicPlaybackState(
        sessionId: name,
        state: PlaybackStatus.paused,
        deviceId: remote ? 'speaker' : HMusicPlaybackState.localDeviceId,
        track: directTrack(name),
        positionMs: position,
        durationMs: 60000,
        volume: 50,
        playMode: PlayMode.listLoop,
        queueIndex: 0,
        queueLength: 1,
        seekEnabled: true,
        updatedAt: 0,
      );
  HMusicPlaybackState state;
  ApiFailure? pauseFailure;
  @override
  Future<HMusicPlaybackState> getState() async => state;
  @override
  Future<HMusicPlaybackState> pause() async {
    if (pauseFailure != null) throw pauseFailure!;
    return state = state.update(status: PlaybackStatus.paused);
  }

  @override
  Future<HMusicPlaybackState> resume() async => state = state.update(
    status: PlaybackStatus.playing,
    streamUrl: 'https://audio.example/${state.track!.id}.mp3',
  );
  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) async => this.state = this.state.update(
    status: state == 'playing' ? PlaybackStatus.playing : PlaybackStatus.paused,
    positionMs: positionMs,
    durationMs: durationMs,
  );
}

void main() {
  const offline = ApiFailure(kind: ApiFailureKind.offline, message: '服务器离线');

  test('两后端往返切换各自保留曲目和毫秒进度，进入时不自动播放', () async {
    final first = _Backend('server', 37000), second = _Backend('direct', 12000);
    var active = first;
    final audio = AudioFixture(RoutedPlaybackRepository(() async => active));
    addTearDown(audio.handler.disposeHandler);
    await audio.handler.ensureServerState();
    await audio.handler.play();
    audio.player.position = const Duration(milliseconds: 41623);
    await audio.handler.transitionBackend(
      () async => active = second,
      preservePosition: true,
    );
    expect(first.state.positionMs, 41623);
    expect(first.state.state, PlaybackStatus.paused);
    expect(audio.player.playing, isFalse);

    await audio.handler.ensureServerState();
    expect(audio.handler.serverState?.track?.id, 'wy:direct');
    expect(audio.handler.effectivePosition.inMilliseconds, 12000);
    await audio.handler.play();
    expect(audio.player.position.inMilliseconds, 12000);
    await audio.handler.transitionBackend(
      () async => active = first,
      preservePosition: true,
    );
    await audio.handler.ensureServerState();
    expect(audio.player.playing, isFalse);
    expect(audio.handler.serverState?.track?.id, 'wy:server');
    expect(audio.handler.effectivePosition.inMilliseconds, 41623);
    await audio.handler.play();
    expect(audio.player.position.inMilliseconds, 41623);
  });

  test('本机已暂停时旧服务器离线不阻断切换，但报告进度未同步', () async {
    final backend = _Backend('server', 37000);
    final audio = AudioFixture(backend);
    addTearDown(audio.handler.disposeHandler);
    final notices = <String>[];
    final subscription = audio.handler.playbackNoticeStream.listen(notices.add);
    addTearDown(subscription.cancel);
    await audio.handler.ensureServerState();
    await audio.handler.play();
    backend.pauseFailure = offline;
    var committed = false;
    await audio.handler.transitionBackend(
      () async => committed = true,
      preservePosition: true,
    );
    await pumpEventQueue();
    expect(committed, isTrue);
    expect(audio.player.playing, isFalse);
    expect(audio.handler.serverState, isNull);
    expect(notices.single, contains('未能同步'));
  });

  test('旧音箱未确认暂停时保留原模式和曲目，不误报切换成功', () async {
    final backend = _Backend('remote', 37000, remote: true)
      ..pauseFailure = offline;
    final audio = AudioFixture(backend);
    addTearDown(audio.handler.disposeHandler);
    await audio.handler.ensureServerState();
    var committed = false;
    await expectLater(
      audio.handler.transitionBackend(
        () async => committed = true,
        preservePosition: true,
      ),
      throwsA(same(offline)),
    );
    expect(committed, isFalse);
    expect(audio.handler.serverState?.track?.id, 'wy:remote');
  });

  test('模式通知触发重订阅时不能沿用旧模式曲目，必须加载目标模式', () async {
    final first = _Backend('server', 37000), second = _Backend('direct', 12000);
    var active = first;
    final audio = AudioFixture(RoutedPlaybackRepository(() async => active));
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        hmusicAudioHandlerProvider.overrideWith((ref) async => audio.handler),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await audio.handler.disposeHandler();
    });
    final directTracks = <String>[];
    container.listen(serverPlaybackStateProvider, (_, value) {
      if (container.read(playbackModeProvider) == PlaybackMode.direct &&
          !value.isLoading &&
          value.value?.track != null) {
        directTracks.add(value.value!.track!.id);
      }
    }, fireImmediately: true);
    await pumpEventQueue();
    expect(audio.handler.serverState?.track?.id, 'wy:server');
    await audio.handler.transitionBackend(() async {
      active = second;
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      await pumpEventQueue();
    }, preservePosition: true);
    await pumpEventQueue();
    expect(
      container.read(serverPlaybackStateProvider).value?.track?.id,
      'wy:direct',
    );
    expect(directTracks, isNot(contains('wy:server')));
  });
}
