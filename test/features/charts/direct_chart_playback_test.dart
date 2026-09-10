import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/charts/data/direct_chart_playback.dart';
import 'package:hmusic/features/charts/models/chart.dart';

import '../../core/playback/support/direct_fixture.dart';
import 'support/direct_chart_fakes.dart';

void main() {
  late DirectFixture f;
  late ChartSearchFixture search;
  late DirectChartPlayback playback;
  const chart = ChartDetail(
    id: 'apple-cn',
    name: '榜单',
    kind: 'apple',
    entries: [
      ChartEntry(rank: 1, title: 'First', artist: 'Singer'),
      ChartEntry(rank: 2, title: 'Second', artist: 'Singer'),
      ChartEntry(rank: 3, title: 'Third', artist: 'Singer'),
    ],
  );
  setUp(() async {
    f = DirectFixture();
    await f.init();
    search = ChartSearchFixture();
    playback = DirectChartPlayback(f.playback, f.queue, search);
  });
  tearDown(() async {
    playback.dispose();
    await f.dispose();
  });

  test(
    'first match starts immediately, later entries append in rank order',
    () async {
      final second = Completer<List<HMusicTrack>>();
      search.reply = (query) async => switch (query) {
        'First Singer' => [directTrack('1')],
        'Second Singer' => await second.future,
        _ => [directTrack('3')],
      };
      final first = await playback.play(chart, 0);
      expect(first.track?.id, 'wy:1');
      expect((await f.queue.getQueue()).items, hasLength(1));
      second.complete([directTrack('2')]);
      await Future<void>.delayed(Duration.zero);
      expect((await f.queue.getQueue()).items.map((item) => item.track.id), [
        'wy:1',
        'wy:2',
        'wy:3',
      ]);
    },
  );

  for (final change in ['replace', 'clear', 'stop', 'dispose']) {
    test(
      '$change cancels late metadata appends without touching the new queue',
      () async {
        final gate = Completer<List<HMusicTrack>>();
        search.reply = (query) async =>
            query == 'First Singer' ? [directTrack('1')] : gate.future;
        await playback.play(chart, 0);
        switch (change) {
          case 'replace':
            await f.queue.replaceQueue(tracks: [directTrack('new')]);
          case 'clear':
            await f.queue.clear();
          case 'stop':
            await f.playback.stop();
          case 'dispose':
            playback.dispose();
        }
        gate.complete([directTrack('late')]);
        await Future<void>.delayed(Duration.zero);
        final queue = await f.queue.getQueue();
        expect(queue.items.any((item) => item.track.id == 'wy:late'), isFalse);
        expect(search.requests, hasLength(2));
      },
    );
  }

  test(
    'queue replacement while the first match is pending prevents late playback',
    () async {
      final gate = Completer<List<HMusicTrack>>();
      search.reply = (_) => gate.future;
      final pending = playback.play(chart, 0);
      final assertion = expectLater(
        pending,
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.code,
            'code',
            'DIRECT_CHART_PLAY_CANCELLED',
          ),
        ),
      );
      await f.queue.replaceQueue(tracks: [directTrack('new')]);
      gate.complete([directTrack('late')]);
      await assertion;
      expect(f.resolver.requests, isEmpty);
      expect((await f.queue.getQueue()).items.single.track.id, 'wy:new');
    },
  );

  test(
    'starting at an entry skips unmatchable rows without changing rank order',
    () async {
      search.reply = (query) async =>
          query == 'Third Singer' ? [directTrack('3')] : [];
      final state = await playback.play(chart, 1);
      expect(search.requests, ['Second Singer', 'Third Singer']);
      expect(state.track?.id, 'wy:3');
      expect(state.queueIndex, 0);
    },
  );

  test(
    'invalid index and no matches leave the existing queue intact',
    () async {
      await f.queue.replaceQueue(tracks: [directTrack('old')]);
      await expectLater(playback.play(chart, 3), throwsA(isA<ApiFailure>()));
      await expectLater(playback.play(chart, 0), throwsA(isA<ApiFailure>()));
      expect((await f.queue.getQueue()).items.single.track.id, 'wy:old');
    },
  );
}
