import 'dart:io';

import 'package:just_audio/just_audio.dart';

class ObservedAudioPlayer extends AudioPlayer {
  ObservedAudioPlayer(this.onLoadError);
  final void Function(Map<String, Object?>) onLoadError;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    try {
      return await super.setAudioSource(
        source,
        preload: preload,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
    } catch (error) {
      onLoadError({
        'type': error.runtimeType.toString(),
        if (error is PlayerException) ...{
          'code': error.code,
          'message': (error.message ?? '').replaceAll(
            RegExp(r'https?://\S+'),
            '<音频地址>',
          ),
        },
      });
      rethrow;
    }
  }
}

Future<Map<String, Object?>> probeNativeStream(String stream) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final uri = Uri.parse(stream);
    final request = await client.getUrl(uri);
    request.headers.set('range', 'bytes=0-63');
    final response = await request.close().timeout(const Duration(seconds: 10));
    final chunks = await response
        .take(1)
        .toList()
        .timeout(const Duration(seconds: 10));
    final bytes = chunks.firstOrNull ?? <int>[];
    return {
      'status': response.statusCode,
      'contentType': response.headers.contentType?.toString(),
      'contentRange': response.headers.value('content-range'),
      'length': response.contentLength,
      'proxied': uri.host == '127.0.0.1',
      'prefix': bytes
          .take(16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    };
  } catch (error) {
    return {'error': error.runtimeType.toString()};
  } finally {
    client.close(force: true);
  }
}
