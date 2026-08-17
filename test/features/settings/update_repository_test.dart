import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/features/settings/data/api_update_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockApiClient apiClient;
  late _MockDio github;
  late ApiUpdateRepository repository;

  setUp(() {
    apiClient = _MockApiClient();
    github = _MockDio();
    repository = ApiUpdateRepository(apiClient: apiClient, github: github);
  });

  test('remoteAppConfig：服务端中转可用时直接采用，不再直连 GitHub', () async {
    when(
      () => apiClient.getMap('/system/app-config', authenticated: false),
    ).thenAnswer(
      (_) async => <String, Object?>{
        'available': true,
        'config': <String, Object?>{
          'minVersion': '9.9.9',
          'notice': '大版本升级',
        },
      },
    );

    final config = await repository.remoteAppConfig();
    expect(config?.minVersion, '9.9.9');
    expect(config?.notice, '大版本升级');
    verifyNever(() => github.get<Object?>(any()));
  });

  test('remoteAppConfig：中转报不可用时退直连镜像', () async {
    when(
      () => apiClient.getMap('/system/app-config', authenticated: false),
    ).thenAnswer(
      (_) async => <String, Object?>{'available': false, 'config': null},
    );
    when(() => github.get<Object?>(any())).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: ''),
        data: <String, Object?>{'minVersion': '1.0.0'},
      ),
    );

    final config = await repository.remoteAppConfig();
    expect(config?.minVersion, '1.0.0');
    verify(() => github.get<Object?>(any())).called(1);
  });

  test('remoteAppConfig：中转不可达（未连接/旧服务端）也退直连镜像', () async {
    when(
      () => apiClient.getMap('/system/app-config', authenticated: false),
    ).thenThrow(Exception('no server'));
    when(() => github.get<Object?>(any())).thenThrow(
      DioException(requestOptions: RequestOptions(path: '')),
    );

    // 两级都失败：按无配置放行（返回 null）。
    expect(await repository.remoteAppConfig(), isNull);
  });
}
