import 'dart:convert';

import 'package:dio/dio.dart';

import 'direct_music_http.dart';
import 'platform_track_mapper.dart';

class LxHttpBridge {
  LxHttpBridge(this._http);
  final DirectMusicHttp _http;
  final Map<String, CancelToken> _pending = {};

  Future<Map<String, Object?>> request(
    String id,
    String url,
    Map<String, Object?> options,
  ) async {
    validateMusicUri(url);
    final token = CancelToken();
    _pending[id] = token;
    try {
      final headers = {...musicMap(options['headers'])};
      Object? data = options['body'];
      if (options['form'] != null) {
        data = options['form'];
        headers['Content-Type'] = Headers.formUrlEncodedContentType;
      } else if (options['formData'] != null) {
        data = FormData.fromMap(musicMap(options['formData']));
      }
      final response = await _http.dio.request<List<int>>(
        url,
        data: data,
        cancelToken: token,
        options: Options(
          method: '${options['method'] ?? 'GET'}'.toUpperCase(),
          headers: headers,
          responseType: ResponseType.bytes,
          receiveTimeout: Duration(
            milliseconds: (musicInt(options['timeout']) ?? 15000).clamp(
              1,
              60000,
            ),
          ),
          validateStatus: (status) => status != null,
        ),
      );
      final bytes = response.data ?? [];
      if (bytes.length > 4 * 1024 * 1024) throw const FormatException();
      Object? body = bytes;
      if (options['binary'] != true) {
        body = utf8.decode(bytes, allowMalformed: true);
        try {
          body = jsonDecode(body as String);
        } on FormatException {
          /* 保留文本响应。 */
        }
      }
      return {
        'statusCode': response.statusCode,
        'statusMessage': response.statusMessage ?? '',
        'headers': response.headers.map.map(
          (key, value) => MapEntry(key, value.join(', ')),
        ),
        'body': body,
        'binary': options['binary'] == true,
      };
    } finally {
      _pending.remove(id);
    }
  }

  void cancel(String id) => _pending.remove(id)?.cancel();
  void close() {
    for (final request in _pending.values) {
      request.cancel();
    }
    _pending.clear();
  }
}
