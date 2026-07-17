import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/network/api_client.dart';
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

  test('playAll 指定本机设备并返回权威 playback', () async {
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
    // 不带 deviceId 时服务端会播到默认设备，本机静音——契约必须锁死。
    // startIndex 未指定时不外发，由服务端默认从 0 开播。
    expect(body, <String, Object?>{'deviceId': 'local-browser'});
    expect(playback.deviceId, 'local-browser');
    expect(playback.state, PlaybackStatus.playing);
  });
}
