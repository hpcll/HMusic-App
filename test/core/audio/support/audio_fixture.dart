import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/local_volume_store.dart';
import 'package:hmusic/core/audio/mode_stream_url_rebaser.dart';
import 'package:hmusic/core/audio/playback_repository.dart';
import 'package:hmusic/core/config/shared_preferences_server_config_store.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:just_audio/just_audio.dart';

class FixtureAudioPlayer extends Fake implements AudioPlayer {
  final events = StreamController<PlayerState>.broadcast(sync: true);
  final List<AudioSource> loads = [];
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  bool playing = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(minutes: 1);
  @override
  Duration get bufferedPosition => position;
  @override
  double volume = 1;
  @override
  double get speed => 1;
  @override
  Stream<PlayerState> get playerStateStream => events.stream;
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  void emit() => events.add(PlayerState(playing, processingState));
  void complete() {
    processingState = ProcessingState.completed;
    position = duration!;
    emit();
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loads.add(source);
    position = initialPosition ?? Duration.zero;
    processingState = ProcessingState.ready;
    emit();
    return duration;
  }

  @override
  Future<void> play() async {
    playing = true;
    emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    emit();
  }

  @override
  Future<void> stop() async {
    playing = false;
    processingState = ProcessingState.idle;
    emit();
  }

  @override
  Future<void> seek(Duration? value, {int? index}) async =>
      position = value ?? Duration.zero;
  @override
  Future<void> setVolume(double value) async => volume = value;
  @override
  Future<void> dispose() => events.close();
}

class _Volume implements LocalVolumeStore {
  @override
  Future<double> read() async => .5;
  @override
  Future<void> write(double volume) async {}
}

class AudioFixture {
  AudioFixture(
    PlaybackRepository repository, {
    int Function()? backendGeneration,
  }) {
    handler = HMusicAudioHandler(
      playbackRepository: repository,
      streamUrlRebaser: ModeStreamUrlRebaser(
        mode: () => PlaybackMode.direct,
        serverConfigStore: SharedPreferencesServerConfigStore(
          preferences: MemoryKeyValueStore(),
        ),
      ),
      localVolumeStore: _Volume(),
      player: player,
      backendGeneration: backendGeneration,
    );
  }
  final FixtureAudioPlayer player = FixtureAudioPlayer();
  late final HMusicAudioHandler handler;
}
