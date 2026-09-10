import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient apiClient;
  late ApiChartsRepository repository;

  setUpAll(() => registerFallbackValue(<String, Object?>{}));

  setUp(() {
    apiClient = _MockApiClient();
    repository = ApiChartsRepository(apiClient: apiClient);
  });

  test('商店版排除 Spotify，即使旧服务端忽略目录参数也不展示', () async {
    repository = ApiChartsRepository(
      apiClient: apiClient,
      includeSpotify: false,
    );
    when(
      () => apiClient.getMap('/charts', query: any(named: 'query')),
    ).thenAnswer(
      (_) async => {
        'charts': [
          {'id': 'family', 'name': '家庭热播', 'kind': 'family'},
          {
            'id': 'spotify-top-short',
            'name': '最近常听',
            'kind': 'spotify-personal',
          },
        ],
      },
    );
    final charts = await repository.getCharts();
    expect(charts.map((chart) => chart.id), ['family']);
    verify(
      () => apiClient.getMap('/charts', query: {'includeSpotify': false}),
    ).called(1);
    await expectLater(
      repository.getChart('spotify-top-short'),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      repository.playAll('spotify-top-short'),
      throwsA(isA<ApiFailure>()),
    );
    verifyNever(() => apiClient.getMap('/charts/spotify-top-short'));
  });

  test('个人版通过统一榜单接口解码 Spotify，详情保留元数据供搜索播放', () async {
    when(() => apiClient.getMap('/charts/spotify-top-short')).thenAnswer(
      (_) async => {
        'id': 'spotify-top-short',
        'name': '最近常听',
        'kind': 'spotify-personal',
        'entries': [
          {'rank': 1, 'title': '晴天', 'artist': '周杰伦'},
        ],
      },
    );
    final chart = await repository.getChart('spotify-top-short');
    expect(chart.entries.single.title, '晴天');
    expect(chart.entries.single.track, isNull);
  });

  test('playAll 不带 deviceId（服务端 resolve 所选默认设备）并返回权威 playback', () async {
    when(
      () => apiClient.postMap('/charts/hot/play', body: any(named: 'body')),
    ).thenAnswer(
      (_) async => <String, Object?>{
        'queue': <String, Object?>{},
        'playback': <String, Object?>{
          'sessionId': 's1',
          'deviceId': 'local-browser',
          'state': 'playing',
          'positionMs': 0,
          'durationMs': 0,
          'volume': 1,
          'playMode': 'list_loop',
          'queueIndex': 0,
          'queueLength': 30,
          'seekEnabled': true,
          'updatedAt': 1700000000000,
        },
      },
    );

    final playback = await repository.playAll('hot');

    final body =
        verify(
              () => apiClient.postMap(
                '/charts/hot/play',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    // 不带 deviceId：服务端 resolve 用户选定的默认设备。硬编码本机会把已选
    // 音箱的播放目标劫持回手机（音箱不停 + 本机开播 = 双端同响）——契约锁死。
    // startIndex 未指定时不外发，由服务端默认从 0 开播。
    expect(body, isEmpty);
    expect(playback.deviceId, 'local-browser');
    expect(playback.state, PlaybackStatus.playing);
  });
}
