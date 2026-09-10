import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../network/api_failure.dart';

/// 登录专用传输：只接受小米 Passport/STS 地址，禁用自动跳转，敏感错误不向上透传。
class MiPassportHttp {
  MiPassportHttp({HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;
  final CookieJar cookies = CookieJar();
  static const accountBase = 'https://account.xiaomi.com';
  static const _stsHosts = {
    'api.mina.mi.com',
    'api2.mina.mi.com',
    'sts.api.io.mi.com',
  };

  static Uri accountUri(String path) {
    final uri = Uri.parse(accountBase).resolve(path);
    if (uri.scheme != 'https' ||
        uri.host != 'account.xiaomi.com' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasFragment) {
      throw invalidResponse;
    }
    return uri;
  }

  static Uri stsUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !_stsHosts.contains(uri.host) ||
        uri.path != '/sts' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasFragment) {
      throw invalidResponse;
    }
    return uri;
  }

  Future<Response<Object?>> request(
    Uri uri, {
    Map<String, Object?>? form,
    bool bytes = false,
    String? userAgent,
  }) async {
    if (uri.host == 'account.xiaomi.com') {
      accountUri(uri.toString());
    } else {
      stsUri(uri.toString());
    }
    try {
      final pairs = await cookies.loadForRequest(uri);
      // Dio 对 Object? 泛型强制使用 JSON；dynamic 才保留 plain/bytes 配置。
      final response = await _dio.requestUri<dynamic>(
        uri,
        data: form,
        options: Options(
          method: form == null ? 'GET' : 'POST',
          responseType: bytes ? ResponseType.bytes : ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'User-Agent':
                userAgent ??
                'APP/com.xiaomi.mihome APPV/6.0.103 iosPassportSDK/3.9.0 iOS/14.4 miHSTS',
            if (pairs.isNotEmpty)
              'Cookie': pairs.map((c) => '${c.name}=${c.value}').join('; '),
          },
        ),
      );
      await cookies.saveFromResponse(uri, responseCookies(response.headers));
      return response;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final sts = uri.path == '/sts';
      final kind = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => ApiFailureKind.timeout,
        DioExceptionType.connectionError => ApiFailureKind.offline,
        DioExceptionType.badResponse when status == 401 || status == 403 =>
          ApiFailureKind.unauthorized,
        _ => ApiFailureKind.server,
      };
      throw ApiFailure(
        kind: kind,
        code: status == null
            ? 'MI_DIRECT_AUTH_REQUEST_FAILED'
            : sts
            ? 'MI_DIRECT_STS_REJECTED'
            : 'MI_DIRECT_AUTH_HTTP_REJECTED',
        statusCode: status,
        details: {'stage': sts ? 'sts' : 'passport'},
        message: switch (status) {
          429 => '小米登录请求过于频繁，请稍后重试',
          final code? when code >= 500 => '小米登录服务暂时不可用（HTTP $code），请稍后重试',
          final code? =>
            sts ? '小米登录凭据交换失败（HTTP $code），请重新登录' : '小米登录请求未被接受（HTTP $code），请重试',
          null =>
            kind == ApiFailureKind.timeout
                ? '连接小米登录服务超时，请检查网络后重试'
                : '无法连接小米登录服务，请检查网络后重试',
        },
      );
    }
  }

  static List<Cookie> responseCookies(Headers headers) {
    final received = <Cookie>[];
    for (final header in headers[HttpHeaders.setCookieHeader] ?? <String>[]) {
      try {
        received.add(Cookie.fromSetCookieValue(header));
      } on FormatException {
        // 单个格式损坏的 Cookie 不应丢掉其他有效的认证 Cookie。
      }
    }
    return received;
  }

  static Map<String, dynamic> decode(Object? value) {
    try {
      if (value is! String) throw invalidResponse;
      final body = value.trim().replaceFirst(
        RegExp(r"^(?:&&&START&&&|\)\]\}',?)\s*"),
        '',
      );
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) throw invalidResponse;
      return json;
    } on FormatException {
      throw invalidResponse;
    }
  }

  void close() => _dio.close(force: true);

  static const invalidResponse = ApiFailure(
    kind: ApiFailureKind.invalidResponse,
    code: 'MI_DIRECT_AUTH_INVALID_RESPONSE',
    message: '小米登录响应无效，请重新登录',
  );
}
