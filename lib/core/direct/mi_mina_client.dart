import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/api_failure.dart';
import 'mi_direct_device.dart';
import 'mi_direct_session.dart';
import 'playback/mi_mico_headers.dart';

/// 旧版 MiIoTService 的 MiNA 传输；独立客户端，不使用 Server Bearer/401 回调。
class MiMinaClient {
  MiMinaClient({HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          followRedirects: false,
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;
  final StreamController<MiDirectSession> _expiredSessions =
      StreamController.broadcast();
  Stream<MiDirectSession> get expiredSessions => _expiredSessions.stream;

  ApiFailure _sessionExpired(MiDirectSession session) {
    if (!_expiredSessions.isClosed) _expiredSessions.add(session);
    return _expired;
  }

  Future<List<MiDirectDevice>> devices(MiDirectSession session) async {
    final result = await _request(
      session,
      'https://api.mina.mi.com/admin/v2/device_list',
    );
    if (result is! List) throw _invalidResponse;
    final devices = <MiDirectDevice>[];
    for (final entry in result) {
      if (entry is! Map<String, dynamic>) throw _invalidResponse;
      final device = MiDirectDevice.fromJson(entry);
      if (device.id.isNotEmpty && device.did.isNotEmpty) devices.add(device);
    }
    return devices;
  }

  Future<Object?> ubus(
    MiDirectSession session, {
    required String deviceId,
    required String method,
    required Map<String, Object?> message,
  }) => _request(
    session,
    'https://api2.mina.xiaoaisound.com/remote/ubus',
    body: {
      'deviceId': deviceId,
      'method': method,
      'path': 'mediaplayer',
      'message': jsonEncode(message),
      'requestId': 'app_ios_${DateTime.now().microsecondsSinceEpoch}',
    },
  );

  Future<Object?> _request(
    MiDirectSession session,
    String url, {
    Map<String, Object?>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        url,
        data: body,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Cookie': session.cookie,
            'User-Agent':
                'MiHome/6.0.103 (com.xiaomi.mihome; build:6.0.103.1; iOS 14.4.0) Alamofire/6.0.103 MICO/iOSApp/appStore/6.0.103',
            ...?headers,
          },
        ),
      );
      Object? payload = response.data;
      if (payload is String) payload = jsonDecode(payload);
      if (payload is! Map<String, dynamic>) throw _invalidResponse;
      final code = payload['code'];
      if (code == 401 || code == '401') throw _sessionExpired(session);
      if (code != 0) {
        throw const ApiFailure(
          kind: ApiFailureKind.server,
          code: 'MI_DIRECT_REJECTED',
          message: '小米设备请求未成功，请刷新设备状态后重试',
        );
      }
      return payload['data'];
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) throw _sessionExpired(session);
      throw ApiFailure(
        kind: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout => ApiFailureKind.timeout,
          DioExceptionType.connectionError => ApiFailureKind.offline,
          _ => ApiFailureKind.server,
        },
        code: 'MI_DIRECT_REQUEST_FAILED',
        message: '无法完成小米设备请求，请检查网络或刷新设备状态',
      );
    } on FormatException {
      throw _invalidResponse;
    }
  }

  void close() {
    _dio.close(force: true);
    unawaited(_expiredSessions.close());
  }

  Future<Object?> officialOperation(
    MiDirectSession session, {
    required MiDirectDevice device,
    required String instanceId,
    required Map<String, Object?> message,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.https('api2.mina.xiaoaisound.com', '/remote/ubus', {
      'timestamp': '$timestamp',
      'requestId': 'hmusic_${DateTime.now().microsecondsSinceEpoch}',
    });
    return _request(
      session,
      url.toString(),
      headers: miMicoHeaders(session, device, instanceId),
      body: {
        'deviceId': device.id,
        'path': 'mediaplayer',
        'method': 'player_play_operation',
        'message': jsonEncode(message),
      },
    );
  }

  static const _expired = ApiFailure(
    kind: ApiFailureKind.unauthorized,
    code: 'MI_DIRECT_SESSION_EXPIRED',
    message: '小米直连会话已失效，请重新登录',
  );
  static const _invalidResponse = ApiFailure(
    kind: ApiFailureKind.invalidResponse,
    code: 'MI_DIRECT_INVALID_RESPONSE',
    message: '小米接口返回了无法识别的设备数据',
  );
}
