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
