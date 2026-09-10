part of 'api_client.dart';

extension _ApiClientErrors on ApiClient {
  Future<ApiFailure> _mapDioFailure(
    DioException error, {
    required bool authenticated,
    int? generation,
  }) async {
    if (!_current(generation)) return ApiClient._backendChanged;
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
    // 服务端按版本门槛拒绝服务：当场关强升门（不等门控下一轮自检），并把它
    // 要求的版本透出去。门槛由部署者掌握（见 Server shared/version.ts）。
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
        final token = await _tokenStore.read();
        final sent = error.requestOptions.headers['Authorization'];
        final sameToken =
            sent == (token == null || token.isEmpty ? null : 'Bearer $token');
        if (_current(generation) && sameToken) {
          await _tokenStore.clear();
          if (_current(generation)) await _onUnauthorized?.call();
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
