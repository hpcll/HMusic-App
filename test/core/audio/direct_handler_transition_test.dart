import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/routed_playback_repository.dart';
import 'package:hmusic/core/network/api_failure.dart';

import '../playback/support/direct_fixture.dart';
import 'support/audio_fixture.dart';

void main() {
  late DirectFixture first;
  late AudioFixture audio;
  setUp(() {
    first = DirectFixture();
    audio = AudioFixture(first.playback);
  });
  tearDown(() async {
    await audio.handler.disposeHandler();
    await first.dispose();
  });

  test(
    'local completion reloads the same URL for single-loop and advances only once',
    () async {
      await first.init();
      await audio.handler.playTrack(directTrack('1'));
      await audio.handler.setPlayMode(PlayMode.singleLoop);
      audio.player.complete();
      audio.player.emit();
      await audio.handler.ensureServerState();
      expect(audio.player.loads, hasLength(2));
      expect(audio.player.position, Duration.zero);
      expect(first.resolver.requests, ['wy:1', 'wy:1']);
      expect(audio.player.playing, isTrue);
    },
  );

  test(
    'completion queued behind a manual track change cannot skip the new track',
    () async {
      await first.init();
      await audio.handler.playTrack(directTrack('1'));
      final manual = audio.handler.playTrack(directTrack('2'));
      audio.player.complete();
      await manual;
      await audio.handler.ensureServerState();
      expect(first.resolver.requests, ['wy:1', 'wy:2']);
      expect(audio.handler.serverState?.track?.id, 'wy:2');
    },
  );

  test('failed speaker stop prevents committing a backend switch', () async {
    await first.init(remote: true);
    await audio.handler.playTrack(directTrack('1'));
    first.adapter.rejectStop = true;
    var committed = false;
    await expectLater(
      audio.handler.transitionBackend(() async => committed = true),
      throwsA(isA<ApiFailure>()),
    );
    expect(committed, isFalse);
    expect(audio.handler.serverState?.deviceId, 'speaker');
  });

  test('playlist operations finish before a queued backend switch', () async {
    await first.init();
    final gate = Completer<void>();
    var switched = false;
    final playlist = audio.handler.executePlayback(() async {
      await gate.future;
      return first.playback.playQueue([directTrack('1'), directTrack('2')]);
    });
    final transition = audio.handler.transitionBackend(
      () async => switched = true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(switched, isFalse);
    gate.complete();
    await Future.wait([playlist, transition]);
    expect(switched, isTrue);
    expect(audio.player.playing, isFalse);
    expect((await first.playback.getState()).state, PlaybackStatus.stopped);
  });

  test(
    'old pause and next buttons queued during a switch cannot control the new backend',
    () async {
      final second = DirectFixture();
      addTearDown(second.dispose);
      await audio.handler.disposeHandler();
      var active = first;
      audio = AudioFixture(
        RoutedPlaybackRepository(() async => active.playback),
      );
      await first.init();
      await second.init();
      await audio.handler.playTrack(directTrack('1'));
      final gate = Completer<void>();
      final switchStarted = Completer<void>();
      final transition = audio.handler.transitionBackend(() async {
        switchStarted.complete();
        await gate.future;
        active = second;
      });
      await switchStarted.future;
      final checks = [
        expectLater(audio.handler.pause(), throwsA(isA<ApiFailure>())),
        expectLater(audio.handler.skipToNext(), throwsA(isA<ApiFailure>())),
      ];
      gate.complete();
      await transition;
      await Future.wait(checks);
      expect(second.resolver.requests, isEmpty);
      expect((await second.playback.getState()).track, isNull);
      await audio.handler.playTrack(directTrack('2'));
      expect(second.resolver.requests, ['wy:2']);
    },
  );
}
