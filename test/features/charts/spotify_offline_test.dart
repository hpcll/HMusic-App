import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_playlist_importer.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/charts/data/direct_chart_playback.dart';
import 'package:hmusic/features/charts/data/direct_chart_source.dart';
import 'package:hmusic/features/charts/data/direct_charts_repository.dart';

import '../../core/playback/support/direct_fixture.dart';
import 'support/direct_chart_fakes.dart';

void main() {
  late DirectFixture fixture;
  late ChartHttpFixture http;

  DirectChartsRepository repository() {
    final result = DirectChartsRepository(
      source: DirectChartSource(http, DirectPlaylistImporter(http)),
      playback: DirectChartPlayback(
        fixture.playback,
        fixture.queue,
        ChartSearchFixture(),
      ),
      store: fixture.store,
      now: () => fixture.now,
    );
    addTearDown(result.dispose);
    return result;
  }

  setUp(() {
    fixture = DirectFixture();
    http = ChartHttpFixture();
    http.html =
        '<script id="__NEXT_DATA__">${jsonEncode({
          'props': {
            'pageProps': {
              'state': {
                'data': {
                  'entity': {
                    'id': '37i9dQZEVXbMDoHDwVN2tF',
                    'trackList': [
                      {'entityType': 'track', 'title': '保存的曲目', 'subtitle': '歌手'},
                    ],
                  },
                },
              },
            },
          },
        })}</script>';
  });
  tearDown(() => fixture.dispose());

  const offline = ApiFailure(kind: ApiFailureKind.offline, message: 'offline');

  test(
    'Spotify has a bounded request and an actionable network error',
    () async {
      http.textFailure = offline;
      await expectLater(
        repository().getChart('spotify-global-top'),
        throwsA(
          isA<ApiFailure>()
              .having(
                (error) => error.code,
                'code',
                'DIRECT_SPOTIFY_UNREACHABLE',
              )
              .having((error) => error.message, 'message', contains('先听其他榜单')),
        ),
      );
      expect(http.textTimeout, const Duration(seconds: 8));
      final family = await repository().getChart('family');
      expect(family.entries, isEmpty);
    },
  );

  test('saved Spotify metadata survives restart and offline refresh', () async {
    final original = await repository().getChart('spotify-global-top');
    fixture.elapse(86401);
    http.textFailure = offline;
    final restored = await repository().getChart('spotify-global-top');
    expect(restored.entries.single.title, '保存的曲目');
    expect(restored.updatedAt, original.updatedAt);
    expect(restored.notice, contains('2026-09-09'));
    expect(restored.toJson(), isNot(contains('notice')));
    expect(restored.entries.single.track, isNull);
  });

  test(
    'an invalid saved chart never masks a network failure as an empty list',
    () async {
      await fixture.store.update('spotifyCharts', (data) {
        data['spotify-global-top'] = {
          'id': 'another-chart',
          'entries': 'broken',
        };
      });
      http.textFailure = offline;
      await expectLater(
        repository().getChart('spotify-global-top'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test(
    'a recovered connection replaces the stale chart and its notice',
    () async {
      final repo = repository();
      final original = await repo.getChart('spotify-global-top');
      fixture.elapse(86401);
      http.textFailure = offline;
      expect((await repo.getChart('spotify-global-top')).notice, isNotNull);
      http.textFailure = null;
      http.html = http.html.replaceFirst('保存的曲目', '恢复后的曲目');
      final refreshed = await repo.getChart('spotify-global-top');
      expect(refreshed.entries.single.title, '恢复后的曲目');
      expect(refreshed.notice, isNull);
      expect(refreshed.updatedAt, greaterThan(original.updatedAt!));
      http.requests.clear();
      expect(
        (await repository().getChart(
          'spotify-global-top',
        )).entries.single.title,
        '恢复后的曲目',
      );
      expect(http.requests, isEmpty);
    },
  );

  test(
    'failed refresh preserves saved data and does not persist its notice',
    () async {
      await repository().getChart('spotify-global-top');
      final saved = await fixture.store.read('spotifyCharts');
      fixture.elapse(86401);
      http.textFailure = offline;
      final repo = repository();
      final results = await Future.wait([
        repo.getChart('spotify-global-top'),
        repo.getChart('spotify-global-top'),
      ]);
      expect(results.every((result) => result.notice != null), isTrue);
      expect(await fixture.store.read('spotifyCharts'), saved);
    },
  );

  test(
    'a valid recent saved chart renders without waiting for Spotify',
    () async {
      await repository().getChart('spotify-global-top');
      http.requests.clear();
      http.textFailure = offline;
      final cached = await repository().getChart('spotify-global-top');
      expect(cached.entries.single.title, '保存的曲目');
      expect(http.requests, isEmpty);
    },
  );
}
