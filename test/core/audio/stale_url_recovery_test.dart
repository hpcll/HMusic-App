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

// 直链失效恢复（docs/08 §7）：加载 -11849/装载超时 → 原曲带进度重解析一次 →
// 续播；同曲 60s 内不二次自救，救不回来如实收场（paused 回写 + 全局报错），
// 绝不停留在「正在播放」假象。AudioPlayer 用 mocktail 假身，按 URL 决定成败。
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
  id: 'tx:1',
  source: 'tx',
  sourceTrackId: '1',
  title: '晴天',
  artist: '周杰伦',
  // 快照里的曲目常带上次解析烤存的直链（CDN 时效签名，早已过期）。
  url: 'https://ws.stream.qq.example/stale.mp3?vkey=EXPIRED',
);

HMusicPlaybackState _state({String? streamUrl, int positionMs = 0}) =>
    HMusicPlaybackState(
      sessionId: 'default',
      state: PlaybackStatus.playing,
      positionMs: positionMs,
      durationMs: 231000,
      volume: 60,
      playMode: PlayMode.listLoop,
      queueIndex: 0,
      queueLength: 1,
      seekEnabled: true,
      updatedAt: 0,
      deviceId: 'local-browser',
      track: _track,
      streamUrl: streamUrl,
    );

class _FakePlaybackRepository implements PlaybackRepository {
  _FakePlaybackRepository({
    required this.resumeState,
    required this.playTrackState,
    HMusicPlaybackState? reportLocalState,
  }) : reportLocalState = reportLocalState ?? resumeState;

  final HMusicPlaybackState resumeState;
  final HMusicPlaybackState playTrackState;
  final HMusicPlaybackState reportLocalState;
  final List<({HMusicTrack track, int? queueIndex, int? positionMs})>
  playTrackCalls = <({HMusicTrack track, int? queueIndex, int? positionMs})>[];
  final List<({String? state, int? positionMs})> reportLocalCalls =
      <({String? state, int? positionMs})>[];

  @override
  Future<HMusicPlaybackState> resume() async => resumeState;

  @override
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
  }) async {
    playTrackCalls.add((
      track: track,
      queueIndex: queueIndex,
      positionMs: positionMs,
    ));
    return playTrackState;
  }

  @override
  Future<HMusicPlaybackState> getState() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> pause() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> next() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> previous() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> stop() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> seek(int positionMs) =>
      throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> setPlayMode(PlayMode mode) =>
      throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) async {
    reportLocalCalls.add((state: state, positionMs: positionMs));
    return reportLocalState;
  }
}

_MockAudioPlayer _player({
  required Set<String> failQueries,
  Set<String> hangQueries = const <String>{},
}) {
  final player = _MockAudioPlayer();
  when(
    () => player.playerStateStream,
  ).thenAnswer((_) => const Stream<PlayerState>.empty());
  when(
    () => player.playbackEventStream,
  ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
  when(() => player.setVolume(any())).thenAnswer((_) async {});
  when(() => player.play()).thenAnswer((_) async {});
  when(() => player.pause()).thenAnswer((_) async {});
  when(() => player.processingState).thenReturn(ProcessingState.idle);
  when(() => player.playing).thenReturn(false);
  when(() => player.position).thenReturn(Duration.zero);
  when(() => player.bufferedPosition).thenReturn(Duration.zero);
  when(() => player.speed).thenReturn(1.0);
  when(
    () => player.setAudioSource(
      any(),
      initialPosition: any(named: 'initialPosition'),
    ),
  ).thenAnswer((invocation) async {
    final source = invocation.positionalArguments.first as UriAudioSource;
    if (hangQueries.contains(source.uri.query)) {
      // 上游黑洞：既不成功也不报错，永远悬着。
      return Completer<Duration?>().future;
    }
    if (failQueries.contains(source.uri.query)) {
      throw PlayerException(-11849, 'Operation Stopped', null);
    }
    return null;
  });
  return player;
}

HMusicAudioHandler _handler(
  _FakePlaybackRepository repository,
  _MockAudioPlayer player,
) {
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

  test('过期直链 -11849：原曲带进度重解析一次并续播', () async {
    final repository = _FakePlaybackRepository(
      resumeState: _state(
        streamUrl: 'http://old.host/api/v1/proxy/audio?u=stale',
        positionMs: 42000,
      ),
      playTrackState: _state(
        streamUrl: 'http://old.host/api/v1/proxy/audio?u=fresh',
        positionMs: 42000,
      ),
    );
    final player = _player(failQueries: <String>{'u=stale'});
    final handler = _handler(repository, player);

    await handler.play();

    expect(repository.playTrackCalls, hasLength(1));
    final call = repository.playTrackCalls.single;
    expect(call.positionMs, 42000);
    expect(call.queueIndex, 0);
    // 关键：重解析请求必须剥掉烤存的过期直链，否则服务端 resolveTrack
    // 见 track.url 非空直接短路返回死链，恢复变成原地打转。
    expect(call.track.url, isNull);
    expect(call.track.sourceTrackId, '1');
    verify(() => player.play()).called(1);
  });

  test('重解析后仍失败：60s 去抖不再自救，如实收场并报错', () async {
    final repository = _FakePlaybackRepository(
      resumeState: _state(
        streamUrl: 'http://old.host/api/v1/proxy/audio?u=stale',
        positionMs: 42000,
      ),
      // 重解析给回的还是坏链 → 二次失败不能死循环，也不能停留在「正在播放」。
      playTrackState: _state(
        streamUrl: 'http://old.host/api/v1/proxy/audio?u=stale',
        positionMs: 42000,
      ),
    );
    final player = _player(failQueries: <String>{'u=stale'});
    final handler = _handler(repository, player);
    final notices = <String>[];
    handler.playbackNoticeStream.listen(notices.add);

    await expectLater(handler.play(), throwsA(isA<PlaybackLoadException>()));

    expect(repository.playTrackCalls, hasLength(1));
    verifyNever(() => player.play());
    // 如实收场：暂停本机 player（防周期回写继续谎报 playing）+ 回写 paused
    // 且进度保留在目标点（稍后重试可续）+ 全局通知流报错。
    verify(() => player.pause()).called(1);
    expect(repository.reportLocalCalls, hasLength(1));
    expect(repository.reportLocalCalls.single.state, 'paused');
    expect(repository.reportLocalCalls.single.positionMs, 42000);
    await pumpEventQueue();
    expect(notices, hasLength(1));
    expect(notices.single, contains('音源加载失败'));
  });

  test('resume 无直链且本机未装载：原曲重解析装载续播，不空转', () async {
    final repository = _FakePlaybackRepository(
      resumeState: _state(streamUrl: null, positionMs: 42000),
      playTrackState: _state(
        streamUrl: 'http://old.host/api/v1/proxy/audio?u=fresh',
        positionMs: 42000,
      ),
    );
    final player = _player(failQueries: const <String>{});
    final handler = _handler(repository, player);

    await handler.play();

    expect(repository.playTrackCalls, hasLength(1));
    expect(repository.playTrackCalls.single.positionMs, 42000);
    // 必须真的装载出声，而不是旧路径对空 player 干喊 play()。
    verify(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).called(1);
    verify(() => player.play()).called(1);
  });

  test('装载黑洞 20s 超时：视同失败，重解析续播', () {
    fakeAsync((async) {
      final repository = _FakePlaybackRepository(
        resumeState: _state(
          streamUrl: 'http://old.host/api/v1/proxy/audio?u=hang',
        ),
        playTrackState: _state(
          streamUrl: 'http://old.host/api/v1/proxy/audio?u=fresh',
        ),
      );
      final player = _player(
        failQueries: const <String>{},
        hangQueries: <String>{'u=hang'},
      );
      final handler = _handler(repository, player);

      var done = false;
      unawaited(handler.play().then((_) => done = true));
      async.elapse(const Duration(seconds: 21));

      expect(done, isTrue);
      expect(repository.playTrackCalls, hasLength(1));
      verify(() => player.play()).called(1);
    });
  });
}
