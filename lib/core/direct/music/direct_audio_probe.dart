import 'dart:async';
import 'dart:io';

import '../../network/api_failure.dart';
import 'direct_audio_policy.dart';
import 'direct_resolved_audio.dart';

/// LX 返回地址不等于音频可播；在音质回退链内拒绝空响应和失效地址。
class DirectAudioProbe {
  const DirectAudioProbe();

  Future<void> check(
    DirectResolvedAudio audio, {
    required DateTime deadline,
  }) async {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) throw _timeout;
    final timeout = remaining < const Duration(seconds: 5)
        ? remaining
        : const Duration(seconds: 5);
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = timeout;
    try {
      await _check(client, audio).timeout(timeout);
    } on TimeoutException {
      throw _timeout;
    } on IOException {
      throw const ApiFailure(
        kind: ApiFailureKind.offline,
        code: 'DIRECT_AUDIO_UNAVAILABLE',
        message: '音频地址暂时无法连接',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _check(HttpClient client, DirectResolvedAudio audio) async {
    final request = await client.getUrl(audio.uri);
    request.maxRedirects = 3;
    request.headers.set('accept-encoding', 'identity');
    for (final header in DirectAudioPolicy.headers(audio).entries) {
      if (![
        'host',
        'connection',
        'content-length',
      ].contains(header.key.toLowerCase())) {
        request.headers.set(header.key, header.value);
      }
    }
    request.headers.set('range', 'bytes=0-0');
    final response = await request.close();
    final mime = response.headers.contentType?.mimeType;
    if (![
          HttpStatus.ok,
          HttpStatus.partialContent,
        ].contains(response.statusCode) ||
        response.contentLength == 0 ||
        const ['text/html', 'application/json', 'text/json'].contains(mime)) {
      throw _unavailable(response.statusCode);
    }
    // 上游忽略 Range 时也只读取首个非空块，随后取消，不下载整首歌。
    final bytes = await response.firstWhere(
      (chunk) => chunk.isNotEmpty,
      orElse: () => const <int>[],
    );
    if (bytes.isEmpty) throw _unavailable(response.statusCode);
  }

  static ApiFailure _unavailable(int status) => ApiFailure(
    kind: ApiFailureKind.invalidResponse,
    code: 'DIRECT_AUDIO_UNAVAILABLE',
    statusCode: status,
    message: '音源返回的音频地址已失效或没有音频内容',
  );

  static const _timeout = ApiFailure(
    kind: ApiFailureKind.timeout,
    code: 'DIRECT_AUDIO_UNAVAILABLE',
    message: '音频地址响应超时',
  );
}
