import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/playback_projection.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/features/player/data/api_lyric_repository.dart';
import 'package:hmusic/features/player/data/lyric_repository.dart';
import 'package:hmusic/features/player/models/hmusic_lyric.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';
import 'package:hmusic/features/playlists/data/api_playlists_repository.dart';
import 'package:hmusic/features/settings/data/api_devices_repository.dart';
import 'package:hmusic/features/settings/data/devices_repository.dart';
import 'package:hmusic/features/settings/models/hmusic_device.dart';
import 'package:just_audio/just_audio.dart';

import 'fake_playlists_repository.dart';

const uiTrack = HMusicTrack(
  id: 'test:long',
  source: 'test',
  sourceTrackId: 'long',
  title: '一首很长的歌曲名称 Long Song Title (Live Remastered Version)',
  artist: '一位名字很长的歌手与演奏家',
);

HMusicPlaybackState uiPlayback({
  String deviceId = 'speaker-1',
  String deviceName = '客厅音箱',
  int volume = 60,
  bool seekEnabled = true,
  int durationMs = 231000,
}) => HMusicPlaybackState(
  sessionId: 'default',
  state: PlaybackStatus.playing,
  positionMs: 42000,
  durationMs: durationMs,
  volume: volume,
  playMode: PlayMode.listLoop,
  queueIndex: 0,
  queueLength: 8,
  seekEnabled: seekEnabled,
  updatedAt: 1,
  deviceId: deviceId,
  deviceName: deviceName,
  track: uiTrack,
);

class UiPlayerViewModel implements PlayerViewModel {
  final List<String> calls = <String>[];
  final List<Duration> seeks = <Duration>[];
  final List<double> localVolumes = <double>[];
  final List<int> deviceVolumes = <int>[];
  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> skipToNext() async => calls.add('next');
  @override
  Future<void> skipToPrevious() async => calls.add('previous');
  @override
  Future<void> seek(Duration position) async => seeks.add(position);
  @override
  Future<void> setPlayMode(PlayMode mode) async => calls.add('mode');
  @override
  Future<void> setLocalVolume(double volume) async => localVolumes.add(volume);
  @override
  Future<void> setDeviceVolume(int volume) async => deviceVolumes.add(volume);
  @override
  Future<double> readLocalVolume() async => .75;
}

class UiAudioPlayer extends Fake implements AudioPlayer {
  @override
  double get volume => .75;
  @override
  Stream<double> get volumeStream => Stream.value(.75);
}

class UiAudioHandler extends BaseAudioHandler implements HMusicAudioHandler {
  UiAudioHandler(HMusicPlaybackState state) {
    emit(state);
  }
  late HMusicPlaybackState _state;
  final StreamController<HMusicPlaybackState> _states =
      StreamController.broadcast();
  @override
  final AudioPlayer player = UiAudioPlayer();
  @override
  HMusicPlaybackState get serverState => _state;
  @override
  Stream<HMusicPlaybackState> get serverStateStream => _states.stream;
  @override
  Stream<String> get playbackNoticeStream => const Stream.empty();
  @override
  Duration get effectivePosition => Duration(milliseconds: _state.positionMs);
  @override
  Future<void> ensureServerState() async {}
  void emit(HMusicPlaybackState state) {
    _state = state;
    _states.add(state);
    mediaItem.add(state.track == null ? null : mediaItemForTrack(state.track!));
    playbackState.add(
      PlaybackState(
        playing: state.state == PlaybackStatus.playing,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> applyRemotePlayback(
    HMusicPlaybackState state, {
    bool autoplay = true,
  }) async => emit(state);
  @override
  Future<void> executePlayback(
    Future<HMusicPlaybackState> Function() action, {
    bool autoplay = true,
  }) async => emit(await action());
  @override
  Future<void> disposeHandler() async {
    await _states.close();
    await mediaItem.close();
    await playbackState.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiDevicesRepository implements DevicesRepository {
  final List<String> selections = <String>[];
  @override
  Future<List<HMusicDevice>> getDevices() async => const [
    HMusicDevice(
      id: 'local-browser',
      name: '本机播放',
      type: 'browser',
      isOnline: true,
    ),
    HMusicDevice(
      id: 'speaker-1',
      name: '客厅音箱',
      isOnline: true,
      isDefault: true,
    ),
  ];
  @override
  Future<HMusicPlaybackState> select(String deviceId) async {
    selections.add(deviceId);
    return uiPlayback(deviceId: deviceId);
  }

  @override
  Future<int> refresh() async => 2;
  @override
  Future<void> probe(String deviceId) async {}
}

class _UiLyrics implements LyricRepository {
  @override
  Future<HMusicLyric> fetchLyric(HMusicTrack track) async =>
      const HMusicLyric();
}

class PlaybackUiFixture {
  PlaybackUiFixture({HMusicPlaybackState? state, this.localSupported = true})
    : handler = UiAudioHandler(state ?? uiPlayback());
  final bool localSupported;
  final UiAudioHandler handler;
  final UiPlayerViewModel controller = UiPlayerViewModel();
  final UiDevicesRepository devices = UiDevicesRepository();

  Widget scope(Widget child) => ProviderScope(
    overrides: [
      hmusicAudioHandlerProvider.overrideWith((ref) async => handler),
      playerViewModelProvider.overrideWithValue(controller),
      livePositionProvider.overrideWith(
        (ref) => Stream.value(const Duration(seconds: 42)),
      ),
      clientPlaybackCapabilitiesProvider.overrideWithValue(
        ClientPlaybackCapabilities(supportsLocalPlayback: localSupported),
      ),
      lyricRepositoryProvider.overrideWithValue(_UiLyrics()),
      playlistsRepositoryProvider.overrideWithValue(FakePlaylistsRepository()),
      devicesRepositoryProvider.overrideWithValue(devices),
    ],
    child: child,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(900, 600),
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      scope(
        MaterialApp(
          theme: dark ? HMusicTheme.dark() : HMusicTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }
}
