import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/direct/playback/mi_speaker_status.dart';
import 'package:hmusic/core/network/api_failure.dart';

import 'support/direct_fixture.dart';

void main() {
  late DirectFixture f;
  setUp(() => f = DirectFixture());
  tearDown(() => f.dispose());

  test('object status info exposes progress and string volume', () async {
    await f.init(remote: true);
    await f.playback.playTrack(directTrack('1'));
    f.adapter.statusAsMap = true;
    f.adapter.status['volume'] = '63';
    f.elapse(10);
    f.report(position: 11000);
    final state = await f.playback.getState();
    expect(state.positionMs, 11000);
    expect(state.volume, 63);
    expect(state.state, PlaybackStatus.playing);
  });

  test('invalid status cannot confirm a speaker or advance playback', () async {
    await f.init(remote: true);
    await f.playback.playQueue([directTrack('1'), directTrack('2')]);
    f.adapter.malformedStatus = true;
    f.elapse(70);
    await expectLater(
      f.playback.getState(),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.code,
          'code',
          'MI_DIRECT_STATUS_INVALID',
        ),
      ),
    );
    expect(f.adapter.plays, 1);
  });

  test(
    'all server audio id aliases are accepted, including blank audio_id',
    () {
      for (final key in ['audio_id', 'global_id', 'id']) {
        final status = MiSpeakerStatus({
          'play_song_detail': {'audio_id': '', key: 42},
        });
        expect(status.audioId, '42');
      }
    },
  );

  for (final hardware in ['X08C', 'OH2P', 'S12A']) {
    for (final frozen in [0, 1000]) {
      test(
        '$hardware repeated $frozen ms polls do not postpone auto-next forever',
        () async {
          await f.dispose();
          f = DirectFixture(hardware: hardware);
          await f.init(remote: true);
          await f.playback.playQueue([directTrack('1'), directTrack('2')]);
          HMusicPlaybackState? state;
          for (var count = 0; count < 26; count++) {
            f.elapse(3);
            f.report(position: frozen);
            state = await f.playback.getState();
            if (state.track?.id == 'wy:2') break;
          }
          expect(state?.track?.id, 'wy:2');
          await f.playback.getState();
          expect(f.adapter.plays, 2);
        },
      );
    }
  }

  test(
    'resume after twenty minutes resolves a fresh link and preserves progress/history',
    () async {
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      f.elapse(10);
      f.report(position: 15000);
      await f.playback.getState();
      final paused = await f.playback.pause();
      f.elapse(1201);
      final resumed = await f.playback.resume();
      expect(f.resolver.requests, ['wy:1', 'wy:1']);
      expect(resumed.positionMs, paused.positionMs);
      expect(resumed.state, PlaybackStatus.playing);
      f.elapse(10);
      f.report(position: 25000);
      await f.playback.getState();
      expect((await f.store.read('history'))['events'], hasLength(1));
      expect(
        f.adapter.calls
            .where((call) => call.method == 'player_play_music')
            .last
            .message['media'],
        'app_ios',
      );
    },
  );

  test(
    'fresh resume retains the stream and uses the server iOS operation context',
    () async {
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      await f.playback.pause();
      await f.playback.resume();
      expect(f.resolver.requests, hasLength(1));
      expect(f.adapter.calls.last.message, {
        'action': 'play',
        'media': 'app_ios',
      });
    },
  );

  test(
    'S12A replay resumes by seeking and keeps the new playback identity',
    () async {
      await f.dispose();
      f = DirectFixture(hardware: 'S12A');
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      f.elapse(10);
      f.report(position: 15000);
      await f.playback.getState();
      final paused = await f.playback.pause();
      final resumed = await f.playback.resume();
      expect(resumed.positionMs, paused.positionMs);
      expect(f.adapter.plays, 2);
      expect(f.adapter.calls.last.method, 'player_set_positon');
      f.report(position: 16000);
      f.elapse(9);
      expect((await f.playback.getState()).state, PlaybackStatus.playing);
      expect((await f.store.read('playback'))['remoteAudioId'], 'url-2');
    },
  );

  test(
    'saved custom compatibility models reach the actual speaker command',
    () async {
      await f.dispose();
      f = DirectFixture(hardware: 'L20A');
      await f.init(remote: true);
      await f.store.update(
        'config',
        (data) => data['extraPlayMusicModels'] = ['L20A'],
      );
      await f.playback.playTrack(directTrack('1'));
      expect(
        f.adapter.calls.where((call) => call.method == 'player_play_music'),
        hasLength(1),
      );
    },
  );

  test(
    'ordinary URL resume preserves the learned device id across foreground verification',
    () async {
      await f.dispose();
      f = DirectFixture(hardware: 'L20A');
      await f.init(remote: true);
      await f.playback.playTrack(directTrack('1'));
      f.elapse(10);
      f.report(position: 12000);
      await f.playback.getState();
      await f.playback.pause();
      await f.playback.resume();
      f.playback.foreground = false;
      f.playback.foreground = true;
      expect((await f.playback.getState()).state, PlaybackStatus.playing);
      expect(f.adapter.plays, 1);
    },
  );
}
