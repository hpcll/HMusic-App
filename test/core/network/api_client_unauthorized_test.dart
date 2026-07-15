import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/security/token_store.dart';

class _ThrowingDio implements Dio {
  _ThrowingDio(this._error);

  final Object Function() _error;

  @override
  Future<Response<T>> requestUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    throw _error();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryServerConfigStore implements ServerConfigStore {
  Uri? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<Uri?> read() async => value;

  @override
  Future<void> write(Uri serverBase) async => value = serverBase;
}

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

void main() {
  late _MemoryServerConfigStore configStore;
  late _MemoryTokenStore tokenStore;

  setUp(() {
    configStore = _MemoryServerConfigStore();
    configStore.value = Uri.parse('http://192.168.1.10:8090');
    tokenStore = _MemoryTokenStore();
    tokenStore.value = 'stale-token';
  });

  // 模拟服务端返回 401 + 标准 error 块，构造与 ApiClient._mapDioFailure 同源的 DioException。
  DioException unauthorizedDioError(String message) {
    final response = Response<Map<String, Object?>>(
      requestOptions: RequestOptions(path: '/api/v1/queue'),
      statusCode: 401,
      data: <String, Object?>{
        'error': <String, Object?>{'code': 'UNAUTHORIZED', 'message': message},
      },
    );
    return DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  test('401 clears token and fires the unauthorized handler once', () async {
    var handlerCalls = 0;
    final dio = _ThrowingDio(() => unauthorizedDioError('登录已失效，请重新登录'));
    final client = ApiClient(
      dio: dio,
      serverConfigStore: configStore,
      tokenStore: tokenStore,
      onUnauthorized: () async => handlerCalls++,
    );

    await expectLater(client.getMap('/queue'), throwsA(isA<ApiFailure>()));

    expect(tokenStore.value, isNull);
    expect(handlerCalls, 1);
  });

  test('non-401 server error does not fire the unauthorized handler', () async {
    var handlerCalls = 0;
    final response = Response<Map<String, Object?>>(
      requestOptions: RequestOptions(path: '/api/v1/queue'),
      statusCode: 500,
      data: <String, Object?>{
        'error': <String, Object?>{'code': 'INTERNAL', 'message': 'boom'},
      },
    );
    final dio = _ThrowingDio(
      () => DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      ),
    );
    final client = ApiClient(
      dio: dio,
      serverConfigStore: configStore,
      tokenStore: tokenStore,
      onUnauthorized: () async => handlerCalls++,
    );

    await expectLater(client.getMap('/queue'), throwsA(isA<ApiFailure>()));

    // 500 不清 token、不触发会话失效。
    expect(tokenStore.value, 'stale-token');
    expect(handlerCalls, 0);
  });

  test(
    'missing server base yields invalidConfiguration without handler',
    () async {
      var handlerCalls = 0;
      configStore.value = null;
      final dio = _ThrowingDio(() => StateError('should not be called'));
      final client = ApiClient(
        dio: dio,
        serverConfigStore: configStore,
        tokenStore: tokenStore,
        onUnauthorized: () async => handlerCalls++,
      );

      await expectLater(
        client.getMap('/queue'),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.kind,
            'kind',
            ApiFailureKind.invalidConfiguration,
          ),
        ),
      );
      expect(handlerCalls, 0);
    },
  );
}
