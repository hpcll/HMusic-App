import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/local_volume_store.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/playback_repository.dart';
import 'package:hmusic/core/audio/stream_url_rebaser.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

// 播放页/mini player 的播控回调都是 fire-and-forget（按钮不 await）：
// ApiFailure 必须被 PlayerViewModel 兜住并走全局通知流（壳层 toast），
// 不能变成未捕获异常静默丢失——遥控模式音箱失联/会话过期是常态。
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

class _FailingRepository implements PlaybackRepository {
  @override
  Future<HMusicPlaybackState> pause() async => throw const ApiFailure(
    kind: ApiFailureKind.server,
    message: '小米设备控制请求失败',
  );

  @override
  Future<HMusicPlaybackState> getState() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> resume() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> playTrack(
    HMusicTrack track, {
    int? queueIndex,
    int? positionMs,
    String? deviceId,
  }) => throw UnimplementedError();

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
  Future<HMusicPlaybackState> setVolume(int volume) =>
      throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> reportLocal({
    String? state,
    int? positionMs,
    int? durationMs,
    bool ended = false,
  }) => throw UnimplementedError();
}

void main() {
  test('播控失败：ApiFailure 被兜住并经全局通知流报错，不外抛', () async {
    final player = _MockAudioPlayer();
    when(
      () => player.playerStateStream,
    ).thenAnswer((_) => const Stream<PlayerState>.empty());
    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
    final handler = HMusicAudioHandler(
      playbackRepository: _FailingRepository(),
      streamUrlRebaser: StreamUrlRebaser(
        serverConfigStore: _FakeServerConfigStore(),
      ),
      localVolumeStore: _FakeVolumeStore(),
      player: player,
    );
    final container = ProviderContainer(
      overrides: [
        hmusicAudioHandlerProvider.overrideWith((ref) => Future.value(handler)),
      ],
    );
    addTearDown(container.dispose);
    final notices = <String>[];
    handler.playbackNoticeStream.listen(notices.add);

    // 与真实按钮一致：不 await 也不能出现未捕获异常。
    await container.read(playerViewModelProvider).pause();
    await pumpEventQueue();

    expect(notices.single, '小米设备控制请求失败');
    await handler.disposeHandler();
  });
}
