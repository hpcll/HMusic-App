import 'package:dio/dio.dart';

import '../app_version.dart';
import '../config/server_config_store.dart';
import '../security/token_store.dart';
import 'api_failure.dart';

typedef UnauthorizedHandler = Future<void> Function();

// 服务端以 403 APP_VERSION_TOO_OLD 拒绝老版本时回调，参数是它要求的最低版本。
typedef VersionRejectedHandler = void Function(String minAppVersion);

// 每个请求自报 App 版本，供服务端做老版本门禁（Server 侧
// shared/app-version-guard.ts）。不带此头的客户端（web 端、音箱、兼容层）放行。
const String kAppVersionHeader = 'X-HMusic-App-Version';

class ApiClient {
  ApiClient({
    required Dio dio,
    required ServerConfigStore serverConfigStore,
    required TokenStore tokenStore,
    UnauthorizedHandler? onUnauthorized,
  }) : _dio = dio,
       _serverConfigStore = serverConfigStore,
       _tokenStore = tokenStore,
       _onUnauthorized = onUnauthorized;

  final Dio _dio;
  final ServerConfigStore _serverConfigStore;
  final TokenStore _tokenStore;
  UnauthorizedHandler? _onUnauthorized;
  VersionRejectedHandler? _onVersionRejected;

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
    try {
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
      final response = await _dio.requestUri<Object?>(
        _buildUri(base, path, null),
        data: form,
        options: Options(method: 'POST', headers: headers),
        onSendProgress: onProgress,
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw await _mapDioFailure(error, authenticated: true);
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
    try {
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

      final response = await _dio.requestUri<Object?>(
        _buildUri(base, path, query),
        data: body,
        options: Options(method: method, headers: headers),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw await _mapDioFailure(error, authenticated: authenticated);
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

  Future<ApiFailure> _mapDioFailure(
    DioException error, {
    required bool authenticated,
  }) async {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiFailure(
        kind: ApiFailureKind.timeout,
        message: '连接服务器超时，请检查地址和网络',
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiFailure(
        kind: ApiFailureKind.offline,
        message: '连不上服务器，检查地址和网络后重试',
      );
    }

    final statusCode = error.response?.statusCode;
    final payload = _tryMap(error.response?.data);
    final nestedError = _tryMap(payload?['error']);
    final code = nestedError?['code'] as String?;
    final message = nestedError?['message'] as String?;
    // 服务端拒绝老版本：当场关强升门（不等下一轮门控自检），并把要求的版本
    // 透出去。这条门改客户端 UI 绕不掉——业务接口全部 403。
    if (statusCode == 403 && code == 'APP_VERSION_TOO_OLD') {
      final details = _tryMap(nestedError?['details']);
      final required = '${details?['minAppVersion'] ?? ''}';
      _onVersionRejected?.call(required);
      return ApiFailure(
        kind: ApiFailureKind.server,
        message: message ?? '当前 App 版本过旧，请升级后使用',
        code: code,
        statusCode: statusCode,
        details: nestedError?['details'],
      );
    }
    if (statusCode == 401) {
      // 只有带凭据的请求收到 401 才意味着「本会话失效」。未认证探测
      //（连接页探活、局域网扫描）撞上陌生设备的 401 不能清 token 登出。
      if (authenticated) {
        await _tokenStore.clear();
        final handler = _onUnauthorized;
        if (handler != null) {
          // SessionController 内部去重，这里重复触发也安全。
          await handler();
        }
      }
      return ApiFailure(
        kind: ApiFailureKind.unauthorized,
        message: message ?? '登录已失效，请重新登录',
        code: code ?? 'UNAUTHORIZED',
        statusCode: statusCode,
        details: nestedError?['details'],
      );
    }
    return ApiFailure(
      kind: ApiFailureKind.server,
      message: message ?? '服务器请求失败 (${statusCode ?? '未知状态'})',
      code: code,
      statusCode: statusCode,
      details: nestedError?['details'],
    );
  }

  Map<String, Object?>? _tryMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map<String, dynamic>) return Map<String, Object?>.from(value);
    return null;
  }
}
