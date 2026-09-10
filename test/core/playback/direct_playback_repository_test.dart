import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/direct/playback/mi_speaker_status.dart';
import 'package:hmusic/core/network/api_failure.dart';

import 'support/direct_fixture.dart';

void main() {
  late DirectFixture f;
  setUp(() => f = DirectFixture());
  tearDown(() => f.dispose());

  test(
    'nested Xiaomi position and duration retain milliseconds and missing values',
    () {
      final status = MiSpeakerStatus({
        'status': '1',
        'play_song_detail': {
          'position': 4500,
          'duration': '61000',
          'audio_id': 42,
        },
      });
      expect(status.positionMs, 4500);
      expect(status.durationMs, 61000);
      expect(status.audioId, '42');
      expect(MiSpeakerStatus({'status': 1}).positionMs, isNull);
    },
  );

  test(
    'local playback uses existing queue/report interface without Xiaomi controls',
    () async {
      await f.init();
      final first = await f.playback.playTrack(directTrack('1'));
      expect(first.isLocalDevice, isTrue);
      expect(first.streamUrl, 'https://audio.example/wy:1.mp3');
      await f.playback.reportLocal(
        state: 'playing',
        positionMs: 2300,
        durationMs: 60000,
      );
      expect((await f.playback.pause()).state, PlaybackStatus.paused);
      expect((await f.playback.resume()).positionMs, 2300);
      expect(f.adapter.calls, isEmpty);
    },
  );

  for (final mode in [
    PlayMode.listLoop,
    PlayMode.singleLoop,
    PlayMode.singleOnce,
    PlayMode.sequence,
    PlayMode.shuffle,
  ]) {
    test(
      'local ended follows ${mode.name} and never revives a stopped queue',
      () async {
        await f.init();
        await f.playback.playQueue([
          directTrack('1'),
          directTrack('2'),
        ], startIndex: 1);
        await f.playback.setPlayMode(mode);
        final next = await f.playback.reportLocal(ended: true);
        if (mode == PlayMode.singleOnce || mode == PlayMode.sequence) {
          expect(next.state, PlaybackStatus.stopped);
          expect(
            (await f.playback.reportLocal(ended: true)).state,
            PlaybackStatus.stopped,
          );
        } else {
          expect(next.queueIndex, mode == PlayMode.singleLoop ? 1 : 0);
          expect(next.state, PlaybackStatus.playing);
        }
      },
    );
  }

  test(
    'same track duplicated in queue honors the selected occurrence',
    () async {
      await f.init();
      final track = directTrack('1');
      await f.queue.replaceQueue(tracks: [track, track]);
      expect((await f.playback.playTrack(track, queueIndex: 1)).queueIndex, 1);
    },
  );

  test(
    'remote pause failure leaves device and selected mode unchanged',
    () async {
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      f.adapter.rejectStop = true;
      await expectLater(
        f.playback.selectDevice('local-browser'),
        throwsA(isA<ApiFailure>()),
      );
      expect(await f.devices.selectedId(), 'speaker');
      expect((await f.playback.getState()).deviceId, 'speaker');
    },
  );

  test(
    'remote nested progress, seek guard and loop completion advance once',
    () async {
      await f.init(remote: true);
      await f.playback.playQueue([directTrack('1'), directTrack('2')]);
      f.elapse(10);
      f.report(position: 10000);
      expect((await f.playback.getState()).positionMs, 10000);
      await f.playback.seek(40000);
      f.report(position: 10000, status: 2);
      final guarded = await f.playback.getState();
      expect(guarded.positionMs, greaterThanOrEqualTo(40000));
      expect(guarded.state, PlaybackStatus.playing);
      f.elapse(15);
      f.report(position: 58000, status: 1);
      await f.playback.getState();
      f.elapse(3);
      f.report(position: 1000);
      final next = await f.playback.getState();
      expect(next.track?.id, 'wy:2');
      await f.playback.getState();
      expect(f.adapter.plays, 2);
    },
  );

  test(
    'external content relinquishes control and mode stop never stops that content',
    () async {
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      f.elapse(10);
      f.report(audioId: 'voice-assistant-news', position: 12000);
      expect((await f.playback.getState()).state, PlaybackStatus.paused);
      f.adapter.calls.clear();
      await f.playback.stop();
      expect(f.adapter.calls, isEmpty);
    },
  );

  test(
    'foreground resume verifies identity and never catches up multiple songs',
    () async {
      await f.init(remote: true);
      await f.playback.playQueue([
        directTrack('1'),
        directTrack('2'),
        directTrack('3'),
      ]);
      f.playback.foreground = false;
      f.elapse(200);
      await f.playback.getState();
      expect(f.adapter.plays, 1);
      f.playback.foreground = true;
      f.report(position: 60000);
      await f.playback.getState();
      await f.playback.getState();
      expect(f.adapter.plays, lessThanOrEqualTo(2));
      expect(f.adapter.plays, 2);
    },
  );

  test(
    'in-flight status returning after suspension cannot advance the queue',
    () async {
      await f.init(remote: true);
      await f.playback.playQueue([directTrack('1'), directTrack('2')]);
      f.elapse(65);
      f.report(position: 60000);
      final gate = f.adapter.statusGate = Completer<void>();
      final pending = f.playback.getState();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      f.playback.foreground = false;
      gate.complete();
      await pending;
      expect(f.adapter.plays, 1);
    },
  );

  test(
    'cold restart restores queue without autoplay and only reattaches matching remote id',
    () async {
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      f.elapse(10);
      f.report(position: 12000);
      await f.playback.getState();
      f.account.cachedAccount = null;
      final restored = f.createPlayback();
      expect((await restored.getState()).state, PlaybackStatus.playing);
      expect(f.adapter.plays, 1);
      await restored.close();
      final mismatched = f.createPlayback();
      f.report(audioId: 'another-app');
      expect((await mismatched.getState()).state, PlaybackStatus.paused);
      f.adapter.calls.clear();
      await mismatched.stop();
      expect(f.adapter.calls, isEmpty);
      await mismatched.close();
    },
  );

  test(
    'device-assigned URL id is learned without comparing it to a fabricated hash',
    () async {
      await f.dispose();
      f = DirectFixture(hardware: 'L20A');
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      f.elapse(10);
      f.report(position: 10000);
      final state = await f.playback.getState();
      expect(state.state, PlaybackStatus.playing);
      expect((await f.store.read('playback'))['remoteAudioId'], 'url-1');
    },
  );

  test('OH2 replay-on-resume starts at actual zero and rejects seek', () async {
    await f.dispose();
    f = DirectFixture(hardware: 'OH2P');
    await f.init(remote: true);
    await f.playback.playTrack(directTrack('1'));
    f.elapse(10);
    await f.playback.pause();
    expect((await f.playback.resume()).positionMs, 0);
    await expectLater(f.playback.seek(2000), throwsA(isA<ApiFailure>()));
  });

  test(
    'non-idempotent Xiaomi timeout is not retried or automatically advanced',
    () async {
      await f.init(remote: true);
      f.adapter.timeoutMethod = 'player_play_music';
      await expectLater(
        f.playback.playTrack(directTrack('1')),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        f.adapter.calls.where((call) => call.method == 'player_play_music'),
        hasLength(1),
      );
      f.elapse(100);
      expect((await f.playback.getState()).state, PlaybackStatus.paused);
    },
  );
}
