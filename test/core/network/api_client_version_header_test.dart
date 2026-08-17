import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/app_version.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/security/token_store.dart';

class _FixedConfigStore implements ServerConfigStore {
  @override
  Future<void> clear() async {}

  @override
  Future<Uri?> read() async => Uri.parse('http://127.0.0.1:6650');

  @override
  Future<void> write(Uri serverBase) async {}
}

class _FixedTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'token';

  @override
  Future<void> write(String token) async {}
}

// 用 Dio 拦截器伪造响应：不起真服务器也能验请求头与错误归一。
ApiClient _client({
  required Response<Object?> Function(RequestOptions options) respond,
  List<RequestOptions>? captured,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        captured?.add(options);
        final response = respond(options);
        if (response.statusCode! >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(response);
      },
    ),
  );
  return ApiClient(
    dio: dio,
    serverConfigStore: _FixedConfigStore(),
    tokenStore: _FixedTokenStore(),
  );
}

void main() {
  test('每个请求自报 App 版本头（服务端老版本门禁的依据）', () async {
    final captured = <RequestOptions>[];
    final client = _client(
      captured: captured,
      respond: (options) => Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: <String, Object?>{'ok': true},
      ),
    );

    await client.getMap('/system/info', authenticated: false);
    expect(captured.single.headers[kAppVersionHeader], kAppVersion);
  });

  test('403 APP_VERSION_TOO_OLD：触发强升回调并带上要求的版本', () async {
    final rejected = <String>[];
    final client = _client(
      respond: (options) => Response<Object?>(
        requestOptions: options,
        statusCode: 403,
        data: <String, Object?>{
          'error': <String, Object?>{
            'code': 'APP_VERSION_TOO_OLD',
            'message': '版本过旧',
            'details': <String, Object?>{'minAppVersion': '9.0.0'},
          },
        },
      ),
    );
    client.registerVersionRejectedHandler(rejected.add);

    await expectLater(
      client.getMap('/playback/state'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.code,
          'code',
          'APP_VERSION_TOO_OLD',
        ),
      ),
    );
    expect(rejected, <String>['9.0.0']);
  });

  test('其它 403 不误触强升门', () async {
    final rejected = <String>[];
    final client = _client(
      respond: (options) => Response<Object?>(
        requestOptions: options,
        statusCode: 403,
        data: <String, Object?>{
          'error': <String, Object?>{'code': 'FORBIDDEN', 'message': '不允许'},
        },
      ),
    );
    client.registerVersionRejectedHandler(rejected.add);

    await expectLater(client.getMap('/playback/state'), throwsA(isA<ApiFailure>()));
    expect(rejected, isEmpty);
  });
}
