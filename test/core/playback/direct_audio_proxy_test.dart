import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_audio_proxy.dart';
import 'package:hmusic/core/direct/music/direct_track_resolver.dart';

void main() {
  test(
    'proxy preserves Range/206, HEAD, headers and rejects unregistered tokens',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <String>[];
      final subscription = server.listen((request) async {
        seen.add(
          '${request.method}:${request.headers.value('range')}:${request.headers.value('referer')}',
        );
        request.response.headers.set('content-type', 'audio/mpeg');
        request.response.headers.set('accept-ranges', 'bytes');
        if (request.headers.value('range') != null) {
          request.response.statusCode = 206;
          request.response.headers.set('content-range', 'bytes 2-4/6');
          request.response.contentLength = 3;
          request.response.add([2, 3, 4]);
        } else {
          request.response.contentLength = 6;
          if (request.method != 'HEAD') {
            request.response.add([0, 1, 2, 3, 4, 5]);
          }
        }
        await request.response.close();
      });
      final proxy = DirectAudioProxy(), client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await proxy.dispose();
        await server.close(force: true);
        await subscription.cancel();
      });
      final audio = DirectResolvedAudio(
        Uri.parse('http://127.0.0.1:${server.port}/audio'),
        headers: {'Referer': 'https://music.example/'},
      );
      final urls = await Future.wait([
        proxy.address(audio),
        proxy.address(audio),
      ]);
      expect(urls[0].port, urls[1].port);
      expect(urls[0].path, isNot(urls[1].path));
      final request = await client.getUrl(urls[0]);
      request.headers.set('range', 'bytes=2-4');
      final response = await request.close();
      expect(response.statusCode, 206);
      expect(response.contentLength, 3);
      expect(response.headers.value('content-range'), 'bytes 2-4/6');
      expect(await response.expand((bytes) => bytes).toList(), [2, 3, 4]);
      final head = await (await client.headUrl(urls[1])).close();
      expect(head.contentLength, 6);
      expect(await head.expand((bytes) => bytes).toList(), isEmpty);
      expect(seen, [
        'GET:bytes=2-4:https://music.example/',
        'HEAD:null:https://music.example/',
      ]);
      for (final invalid in [
        urls[0].replace(path: '/audio/invalid'),
        urls[0].replace(query: 'url=https://other.example'),
      ]) {
        final rejected = await (await client.getUrl(invalid)).close();
        expect(rejected.statusCode, 404);
        await rejected.drain<void>();
      }
      expect(seen, hasLength(2));
      await proxy.close();
      await expectLater(
        () async => (await client.getUrl(urls[0])).close(),
        throwsA(isA<IOException>()),
      );
    },
  );

  test(
    'bounded token registry expires oldest entries and can restart after closing',
    () async {
      final proxy = DirectAudioProxy(), client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await proxy.dispose();
      });
      final audio = DirectResolvedAudio(
        Uri.parse('https://audio.example/a'),
        headers: {'X-Fixture': '1'},
      );
      final oldest = await proxy.address(audio);
      for (var i = 0; i < 128; i++) {
        await proxy.address(audio);
      }
      final rejected = await (await client.getUrl(oldest)).close();
      expect(rejected.statusCode, 404);
      await rejected.drain<void>();
      await proxy.close();
      expect((await proxy.address(audio)).path, isNot(oldest.path));
    },
  );
}
