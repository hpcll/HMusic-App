import 'dart:convert';

import 'package:dio/dio.dart';

import '../../network/api_failure.dart';

/// 音乐平台和插件专属传输，永不继承 Server/小米凭据或登录失效处理。
class DirectMusicHttp {
  DirectMusicHttp({HttpClientAdapter? adapter})
    : dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': 'application/json, text/plain, */*',
          },
        ),
      ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
  }

  final Dio dio;

  Future<Map<String, Object?>> json(
    String url, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, Object?>? headers,
  }) async {
    final text = await this.text(
      url,
      query: query,
      body: body,
      headers: headers,
    );
    try {
      var content = text.trim();
      if (!content.startsWith('{')) {
        final start = content.indexOf('('), end = content.lastIndexOf(')');
        if (start >= 0 && end > start) {
          content = content.substring(start + 1, end);
        }
      }
      final result = jsonDecode(content);
      if (result is Map<String, Object?>) return result;
    } on FormatException {
      // 不把上游 HTML、签名 URL 或插件密钥带入可见错误。
    }
    throw const ApiFailure(
      kind: ApiFailureKind.invalidResponse,
      code: 'DIRECT_MUSIC_RESPONSE_INVALID',
      message: '音乐平台返回的数据无法识别',
    );
  }

  Future<String> text(
    String url, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, Object?>? headers,
  }) async {
    validateMusicUri(url);
    try {
      final response = await dio.request<String>(
        url,
        queryParameters: query,
        data: body,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          responseType: ResponseType.plain,
          headers: headers,
        ),
      );
      return response.data ?? '';
    } on DioException catch (error) {
      throw ApiFailure(
        kind:
            error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.connectionTimeout
            ? ApiFailureKind.timeout
            : ApiFailureKind.offline,
        code: 'DIRECT_MUSIC_REQUEST_FAILED',
        message: '无法连接音乐平台，请检查网络后重试',
      );
    }
  }

  void close() => dio.close(force: true);
}

Uri validateMusicUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) {
    throw const ApiFailure(
      kind: ApiFailureKind.invalidConfiguration,
      code: 'DIRECT_AUDIO_URL_INVALID',
      message: '音源地址无效',
    );
  }
  return uri;
}
