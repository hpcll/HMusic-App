import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/local_volume_store.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/playback_repository.dart';
import 'package:hmusic/core/audio/stream_url_rebaser.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/view_models/device_picker_view_model.dart';
import 'package:hmusic/features/settings/data/api_devices_repository.dart';
import 'package:hmusic/features/settings/data/devices_repository.dart';
import 'package:hmusic/features/settings/models/hmusic_device.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

// 播放页设备 sheet 的切换语义：select 必须与设置页同款——服务端切默认设备的
// 返回状态注入 AudioHandler（目标为音箱 → 停本机 player、状态落地）。
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

const HMusicDevice _speaker = HMusicDevice(
  id: 'speaker-1',
  name: '客厅音箱',
  type: 'L06A',
  isOnline: true,
);

HMusicPlaybackState _speakerPlayback() => const HMusicPlaybackState(
  sessionId: 'default',
  state: PlaybackStatus.paused,
  positionMs: 5000,
  durationMs: 231000,
  volume: 60,
  playMode: PlayMode.listLoop,
  queueIndex: 0,
  queueLength: 1,
  seekEnabled: true,
  updatedAt: 0,
  deviceId: 'speaker-1',
  deviceName: '客厅音箱',
  track: HMusicTrack(
    id: 'tx:1',
    source: 'tx',
    sourceTrackId: '1',
    title: '晴天',
    artist: '周杰伦',
  ),
);

class _FakeDevicesRepository implements DevicesRepository {
  final List<String> selectCalls = <String>[];

  @override
  Future<List<HMusicDevice>> getDevices() async => const <HMusicDevice>[
    _speaker,
  ];

  @override
  Future<HMusicPlaybackState> select(String deviceId) async {
    selectCalls.add(deviceId);
    return _speakerPlayback();
  }

  @override
  Future<int> refresh() => throw UnimplementedError();

  @override
  Future<void> probe(String deviceId) => throw UnimplementedError();
}

class _StubPlaybackRepository implements PlaybackRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('select：服务端切设备返回的播放状态注入 handler，本机 player 停', () async {
    final player = _MockAudioPlayer();
    when(
      () => player.playerStateStream,
    ).thenAnswer((_) => const Stream<PlayerState>.empty());
    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.processingState).thenReturn(ProcessingState.idle);
    when(() => player.playing).thenReturn(false);
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.bufferedPosition).thenReturn(Duration.zero);
    when(() => player.speed).thenReturn(1.0);
    when(() => player.dispose()).thenAnswer((_) async {});
    final handler = HMusicAudioHandler(
      playbackRepository: _StubPlaybackRepository(),
      streamUrlRebaser: StreamUrlRebaser(
        serverConfigStore: _FakeServerConfigStore(),
      ),
      localVolumeStore: _FakeVolumeStore(),
      player: player,
    );
    final repository = _FakeDevicesRepository();
    final container = ProviderContainer(
      overrides: [
        devicesRepositoryProvider.overrideWithValue(repository),
        hmusicAudioHandlerProvider.overrideWith((ref) => Future.value(handler)),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(devicePickerViewModelProvider.notifier)
        .select(_speaker);

    expect(ok, isTrue);
    expect(repository.selectCalls, <String>['speaker-1']);
    // 音箱接管：本机静默 + 权威状态落地（不 autoplay）。
    verify(() => player.stop()).called(1);
    expect(handler.serverState?.deviceId, 'speaker-1');
    expect(handler.serverState?.state, PlaybackStatus.paused);
    await handler.disposeHandler();
  });
}
