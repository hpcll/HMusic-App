import 'package:dio/dio.dart';

import '../app_version.dart';
import '../config/server_config_store.dart';
import '../security/token_store.dart';
import 'api_failure.dart';

part 'api_client_errors.dart';

typedef UnauthorizedHandler = Future<void> Function();

// 服务端按版本门槛拒绝服务时回调（403 APP_VERSION_TOO_OLD），参数是它要求的最低版本。
typedef VersionRejectedHandler = void Function(String minAppVersion);

// 每个请求自报 App 版本，供服务端做客户端版本门禁（Server 侧
// shared/app-version-guard.ts）。不带此头的客户端（web 端、音箱、兼容层）放行。
const String kAppVersionHeader = 'X-HMusic-App-Version';

class ApiClient {
  ApiClient({
    required Dio dio,
    required ServerConfigStore serverConfigStore,
    required TokenStore tokenStore,
    UnauthorizedHandler? onUnauthorized,
    Future<void> Function()? beforeRequest,
    int Function()? requestGeneration,
  }) : _dio = dio,
       _serverConfigStore = serverConfigStore,
       _tokenStore = tokenStore,
       _onUnauthorized = onUnauthorized,
       _beforeRequest = beforeRequest,
       _requestGeneration = requestGeneration;

  final Dio _dio;
  final ServerConfigStore _serverConfigStore;
  final TokenStore _tokenStore;
  UnauthorizedHandler? _onUnauthorized;
  VersionRejectedHandler? _onVersionRejected;
  final Future<void> Function()? _beforeRequest;
  final int Function()? _requestGeneration;

  bool _current(int? generation) =>
      generation == null || generation == _requestGeneration?.call();

  void _requireCurrent(int? generation) {
    if (!_current(generation)) throw _backendChanged;
  }

  static const _backendChanged = ApiFailure(
    kind: ApiFailureKind.invalidConfiguration,
    code: 'PLAYBACK_BACKEND_CHANGED',
    message: '播放模式已切换，请重新操作',
  );

  // 由 SessionGuard 注入：401 时触发停本机音频，并经 SessionController 单飞跳登录页。
  void registerUnauthorizedHandler(UnauthorizedHandler handler) {
    _onUnauthorized = handler;
  }

  // 由 appVersionGuard 注入：403 APP_VERSION_TOO_OLD 时当场关强升门。
  // 走注册而非构造注入，避免 apiClient ←→ upgradeGate 形成 provider 依赖环。
  void registerVersionRejectedHandler(VersionRejectedHandler handler) {
    _onVersionRejected = handler;
  }

  Future<Map<String, Object?>> getMap(
    String path, {
    Uri? serverBase,
    Map<String, Object?>? query,
    bool authenticated = true,
  }) {
    return _requestMap(
      'GET',
      path,
      serverBase: serverBase,
      query: query,
      authenticated: authenticated,
    );
  }

  Future<Map<String, Object?>> postMap(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) {
    return _requestMap('POST', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, Object?>> putMap(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) {
    return _requestMap('PUT', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, Object?>> patchMap(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) {
    return _requestMap('PATCH', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, Object?>> deleteMap(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) {
    return _requestMap(
      'DELETE',
      path,
      body: body,
      authenticated: authenticated,
    );
  }

  // multipart 文件上传（曲库上传等）：与 _requestMap 同一套 base/token/错误
  // 归一，附带发送进度回调。字段名固定 file，与 Server @fastify/multipart 对齐。
  Future<Map<String, Object?>> uploadFile(
    String path, {
    required String filePath,
    void Function(int sent, int total)? onProgress,
  }) async {
    int? generation;
    try {
      await _beforeRequest?.call();
      generation = _requestGeneration?.call();
      final base = await _serverConfigStore.read();
      if (base == null) {
        throw const ApiFailure(
          kind: ApiFailureKind.invalidConfiguration,
          message: '尚未配置 HMusic Server',
        );
      }
      final headers = <String, Object?>{kAppVersionHeader: kAppVersion};
      final token = await _tokenStore.read();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final form = FormData.fromMap(<String, Object?>{
        'file': await MultipartFile.fromFile(filePath),
      });
      _requireCurrent(generation);
      final response = await _dio.requestUri<Object?>(
        _buildUri(base, path, null),
        data: form,
        options: Options(method: 'POST', headers: headers),
        onSendProgress: onProgress,
      );
      _requireCurrent(generation);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw await _mapDioFailure(
        error,
        authenticated: true,
        generation: generation,
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.unknown,
        message: '上传失败，请稍后重试',
        details: error,
      );
    }
  }

  Future<Map<String, Object?>> _requestMap(
    String method,
    String path, {
    Uri? serverBase,
    Map<String, Object?>? query,
    Map<String, Object?>? body,
    required bool authenticated,
  }) async {
    // 存储读取（server base / token）也必须在 try 内：钥匙串锁定等底层
    // PlatformException 要归一成 ApiFailure，否则「on ApiFailure 尽力而为」
    // 的调用方（周期上报、ended 推进）会被裸异常击穿。
    int? generation;
    try {
      await _beforeRequest?.call();
      generation = _requestGeneration?.call();
      final base = serverBase ?? await _serverConfigStore.read();
      if (base == null) {
        throw const ApiFailure(
          kind: ApiFailureKind.invalidConfiguration,
          message: '尚未配置 HMusic Server',
        );
      }

      final headers = <String, Object?>{kAppVersionHeader: kAppVersion};
      if (authenticated) {
        final token = await _tokenStore.read();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      _requireCurrent(generation);
      final response = await _dio.requestUri<Object?>(
        _buildUri(base, path, query),
        data: body,
        options: Options(method: method, headers: headers),
      );
      _requireCurrent(generation);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw await _mapDioFailure(
        error,
        authenticated: authenticated,
        generation: generation,
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      throw ApiFailure(
        kind: ApiFailureKind.unknown,
        message: '请求失败，请稍后重试',
        details: error,
      );
    }
  }

  Uri _buildUri(Uri base, String path, Map<String, Object?>? query) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final queryParameters = query?.map(
      (key, value) => MapEntry<String, String>(key, value.toString()),
    );
    return base.replace(
      path: '/api/v1$normalizedPath',
      queryParameters: queryParameters,
    );
  }

  Map<String, Object?> _asMap(Object? data) {
    if (data == null) return <String, Object?>{};
    if (data is Map<String, Object?>) return data;
    if (data is Map<String, dynamic>) return Map<String, Object?>.from(data);
    throw const ApiFailure(
      kind: ApiFailureKind.invalidResponse,
      message: '服务器返回了无法识别的数据',
    );
  }
}
