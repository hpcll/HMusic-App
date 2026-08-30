import 'dart:async';

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

// just_audio 的 play() 直到「播完 / 被暂停 / 被停」才 complete。播放命令链路
// 一旦 await 它，playTrack 就会挂满整首歌：前台 VM 的 acting 互斥锁不放（列表
// 所有播放键变灰 → 只有暂停上一首才能播下一首）、成功 toast 延到暂停那刻才弹
//（暂停了却提示「正在播放」）。这里用永不 complete 的 play() 钉住这条纪律。
class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeAudioSource extends Fake implements AudioSource {}

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
  id: 'tx:2',
  source: 'tx',
  sourceTrackId: '2',
  title: '海屿你',
  artist: '马也_Crabbit',
);

final HMusicPlaybackState _playing = HMusicPlaybackState(
  sessionId: 'default',
  state: PlaybackStatus.playing,
  positionMs: 0,
  durationMs: 210000,
  volume: 60,
  playMode: PlayMode.listLoop,
  queueIndex: 1,
  queueLength: 56,
  seekEnabled: true,
  updatedAt: 0,
  deviceId: 'local-browser',
  track: _track,
  streamUrl: 'http://old.host/api/v1/proxy/audio?u=fresh',
);

class _FakeRepository implements PlaybackRepository {
  int reportLocalCalls = 0;

  @override
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
    String? deviceId,
  }) async => _playing;

  @override
  Future<HMusicPlaybackState> resume() async => _playing;

  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) async {
    reportLocalCalls += 1;
    return _playing;
  }

  @override
  Future<HMusicPlaybackState> getState() async => _playing;

  @override
  Future<HMusicPlaybackState> next() async => _playing;

  @override
  Future<HMusicPlaybackState> previous() async => _playing;

  @override
  Future<HMusicPlaybackState> pause() async => _playing;

  @override
  Future<HMusicPlaybackState> seek(int positionMs) async => _playing;

  @override
  Future<HMusicPlaybackState> setPlayMode(PlayMode mode) async => _playing;

  @override
  Future<HMusicPlaybackState> setVolume(int volume) async => _playing;

  @override
  Future<HMusicPlaybackState> stop() async => _playing;
}

// play() 永不 complete，复刻真机行为：首次开播的 Future 直到歌曲结束才落地。
_MockAudioPlayer _hangingPlayer() {
  final player = _MockAudioPlayer();
  when(
    () => player.playerStateStream,
  ).thenAnswer((_) => const Stream<PlayerState>.empty());
  when(
    () => player.playbackEventStream,
  ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
  when(() => player.setVolume(any())).thenAnswer((_) async {});
  when(() => player.play()).thenAnswer((_) => Completer<void>().future);
  when(() => player.pause()).thenAnswer((_) async {});
  when(() => player.processingState).thenReturn(ProcessingState.ready);
  when(() => player.playing).thenReturn(true);
  when(() => player.position).thenReturn(Duration.zero);
  when(() => player.bufferedPosition).thenReturn(Duration.zero);
  when(() => player.speed).thenReturn(1.0);
  when(
    () => player.setAudioSource(
      any(),
      initialPosition: any(named: 'initialPosition'),
    ),
  ).thenAnswer((_) async => null);
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

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAudioSource());
    registerFallbackValue(Duration.zero);
  });

  test('点播不等 play() 播完就返回（前台互斥锁与成功提示都不再延到暂停）', () async {
    final player = _hangingPlayer();
    final handler = _handler(_FakeRepository(), player);

    await handler
        .playTrack(_track)
        .timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('playTrack 挂在 player.play() 上没返回'),
        );

    verify(() => player.play()).called(1);
    expect(handler.serverState?.track?.id, 'tx:2');
  });

  test('resume 也不等 play() 播完（媒体键/mini player 播放键同一条链路）', () async {
    final player = _hangingPlayer();
    final handler = _handler(_FakeRepository(), player);

    await handler.play().timeout(
      const Duration(seconds: 1),
      onTimeout: () => fail('play 挂在 player.play() 上没返回'),
    );

    verify(() => player.play()).called(1);
  });
}
