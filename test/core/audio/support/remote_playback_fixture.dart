part of '../remote_playback_test.dart';

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

HMusicAudioHandler _handler(
  _FakeRepository repository,
  AudioPlayer player, {
  bool localSupported = true,
}) {
  return HMusicAudioHandler(
    playbackRepository: repository,
    streamUrlRebaser: StreamUrlRebaser(
      serverConfigStore: _FakeServerConfigStore(),
    ),
    localVolumeStore: _FakeVolumeStore(),
    player: player,
    capabilities: ClientPlaybackCapabilities(
      supportsLocalPlayback: localSupported,
    ),
  );
}

class _FakeAudioSource extends Fake implements AudioSource {}
