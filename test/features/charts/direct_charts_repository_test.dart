import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_playlist_importer.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/charts/data/direct_chart_playback.dart';
import 'package:hmusic/features/charts/data/direct_chart_source.dart';
import 'package:hmusic/features/charts/data/direct_charts_repository.dart';
import 'package:hmusic/features/charts/models/chart_catalog.dart';

import '../../core/playback/support/direct_fixture.dart';
import 'support/direct_chart_fakes.dart';

void main() {
  late DirectFixture f;
  late ChartHttpFixture http;
  late DirectChartsRepository repository;

  DirectChartsRepository create({bool spotify = true}) =>
      DirectChartsRepository(
        source: DirectChartSource(http, DirectPlaylistImporter(http)),
        playback: DirectChartPlayback(
          f.playback,
          f.queue,
          ChartSearchFixture(),
        ),
        store: f.store,
        now: () => f.now,
        includeSpotify: spotify,
      );
  setUp(() {
    f = DirectFixture();
    http = ChartHttpFixture();
    repository = create();
  });
  tearDown(() async {
    repository.dispose();
    await f.dispose();
  });

  test(
    'direct discovery exposes all public platforms without inventing personal Spotify charts',
    () async {
      final catalog = await repository.getCharts();
      expect(catalog, hasLength(17));
      expect(discoveryCharts(catalog, 'featured').map((chart) => chart.kind), [
        'spotify-public',
        'family',
        'netease',
        'qq',
        'apple',
      ]);
      expect(
        catalog.where((chart) => chart.kind == 'spotify-personal'),
        isEmpty,
      );
      final store = create(spotify: false);
      addTearDown(store.dispose);
      expect(
        (await store.getCharts()).where(
          (chart) => chart.kind.startsWith('spotify'),
        ),
        isEmpty,
      );
      await expectLater(
        store.getChart('spotify-global-top'),
        throwsA(isA<ApiFailure>()),
      );
      expect(http.requests, isEmpty);
    },
  );

  test('QQ retries an empty current list using the published period', () async {
    http.reply = (_, body) {
      final request = (body as Map)['toplist'] as Map;
      final params = request['param'] as Map;
      if (request['method'] == 'GetAll') {
        return {
          'toplist': {
            'code': 0,
            'data': {
              'group': [
                {
                  'toplist': [
                    {'topId': 26, 'period': '2026-09-09'},
                  ],
                },
              ],
            },
          },
        };
      }
      return {
        'toplist': {
          'code': 0,
          'data': {
            'songInfoList': [
              if (params['period'] == '2026-09-09')
                {
                  'id': 12,
                  'mid': 'music-mid',
                  'title': 'A &amp; B',
                  'interval': 60,
                  'album': {'mid': 'album-mid', 'name': '专辑'},
                  'singer': [
                    {'name': '歌手'},
                  ],
                },
            ],
          },
        },
      };
    };
    final chart = await repository.getChart('qq-hot');
    expect(http.requests, hasLength(3));
    expect(chart.entries.single.title, 'A & B');
    expect(chart.entries.single.track?.sourceTrackId, 'music-mid');
    expect(chart.entries.single.track?.durationMs, 60000);
    expect(chart.entries.single.coverUrl, contains('album-mid'));
  });

  test(
    'Apple caches for a day and preserves last success when upstream fails',
    () async {
      http.reply = (_, _) => {
        'feed': {
          'results': [
            {
              'name': '曲目',
              'artistName': '歌手',
              'artworkUrl100': 'https://image.example/100x100bb.jpg',
            },
          ],
        },
      };
      final chart = await repository.getChart('apple-cn');
      expect(chart.entries.single.track, isNull);
      expect(chart.entries.single.coverUrl, contains('600x600'));
      expect(await repository.getChart('apple-cn'), same(chart));
      expect(http.requests, hasLength(1));
      f.elapse(86401);
      http.reply = (_, _) => throw const ApiFailure(
        kind: ApiFailureKind.offline,
        message: 'offline',
      );
      expect(await repository.getChart('apple-cn'), same(chart));
      expect(http.requests, hasLength(2));
    },
  );

  test(
    'Spotify reads public embedded metadata and never exposes preview URLs as complete songs',
    () async {
      http.html =
          '<script type="application/json" id="__NEXT_DATA__">${jsonEncode({
            'props': {
              'pageProps': {
                'state': {
                  'data': {
                    'entity': {
                      'id': '37i9dQZEVXbMDoHDwVN2tF',
                      'trackList': [
                        {
                          'entityType': 'track',
                          'title': 'Song',
                          'subtitle': 'A,\u00a0B',
                          'audioPreview': {'url': 'https://audio.example/preview.mp3'},
                        },
                      ],
                    },
                  },
                },
              },
            },
          })}</script>';
      final chart = await repository.getChart('spotify-global-top');
      expect(chart.entries.single.title, 'Song');
      expect(chart.entries.single.artist, 'A, B');
      expect(chart.entries.single.track, isNull);
      expect(
        chart.entries.single.toJson().toString(),
        isNot(contains('preview.mp3')),
      );
      expect(
        http.requests.single.url,
        startsWith('https://open.spotify.com/embed/playlist/'),
      );
    },
  );

  test(
    'old Netease numeric ids resolve to the same canonical chart and cache',
    () async {
      http.reply = (_, _) => {
        'playlist': {
          'name': '热歌榜',
          'tracks': [
            {
              'id': 1,
              'name': '曲目',
              'ar': [
                {'name': '歌手'},
              ],
            },
          ],
        },
      };
      final old = await repository.getChart('wy-3778678');
      expect(old.id, 'wy-hot');
      expect(await repository.getChart('wy-hot'), same(old));
      expect(http.requests, hasLength(1));
    },
  );

  test(
    'local hot chart counts thirty-day history and keeps the latest snapshot',
    () async {
      final now = f.now.millisecondsSinceEpoch;
      await f.store.update(
        'history',
        (data) => data['events'] = [
          {
            'track': directTrack('old').toJson(),
            'playedAt': now - const Duration(days: 31).inMilliseconds,
          },
          {'track': directTrack('1').toJson(), 'playedAt': now - 120000},
          {'track': directTrack('2').toJson(), 'playedAt': now - 60000},
          {
            'track': {...directTrack('1').toJson(), 'title': '最新曲名'},
            'playedAt': now,
          },
        ],
      );
      final chart = await repository.getChart('family');
      expect(chart.entries.map((entry) => entry.track?.id), ['wy:1', 'wy:2']);
      expect(chart.entries.first.title, '最新曲名');
      expect(chart.entries.first.playCount, 2);
      expect(http.requests, isEmpty);
    },
  );
}
