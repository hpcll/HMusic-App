import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_audio_probe.dart';
import 'package:hmusic/core/direct/music/direct_resolved_audio.dart';
import 'package:hmusic/core/network/api_failure.dart';

void main() {
  test('音频正文卡住时探测受剩余总预算约束，关闭连接且不泄露签名地址', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final release = Completer<void>();
    server.listen((request) async {
      request.response.headers.set('content-type', 'audio/mpeg');
      request.response.contentLength = 1;
      unawaited(request.response.done.catchError((Object _) {}));
      await request.response.flush();
      await release.future;
      await request.response.close().catchError((Object _) {});
    });
    addTearDown(() async {
      release.complete();
      await server.close(force: true);
    });
    final watch = Stopwatch()..start();
    await expectLater(
      const DirectAudioProbe().check(
        DirectResolvedAudio(
          Uri.parse('http://127.0.0.1:${server.port}/audio?secret=fixture'),
        ),
        deadline: DateTime.now().add(const Duration(milliseconds: 100)),
      ),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.kind, 'kind', ApiFailureKind.timeout)
            .having(
              (failure) => failure.message,
              'message',
              isNot(contains('secret')),
            ),
      ),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
