import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/isolated_lx_runtime.dart';
import 'package:hmusic/core/network/api_failure.dart';

import 'support/lx_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('isolated native JSC plugins', () {
    test(
      'two plugins keep globals and native bridge callbacks separate',
      () async {
        final a = IsolatedLxRuntime(), b = IsolatedLxRuntime();
        addTearDown(() {
          a.close();
          b.close();
        });
        await Future.wait([
          a.start(lxFixtureScript, name: 'plugin-a'),
          b.start(lxFixtureScript, name: 'plugin-b'),
        ]);
        final results = await Future.wait([
          a.request('wy', 'musicUrl', {'delay': 20}),
          b.request('wy', 'musicUrl', {'delay': 5}),
        ]);
        expect((results[0] as Map)['name'], 'plugin-a');
        expect((results[1] as Map)['name'], 'plugin-b');
        expect((results[0] as Map)['count'], 1);
        expect((results[1] as Map)['count'], 1);
        expect((await a.request('wy', 'musicUrl', {}) as Map)['count'], 2);
      },
    );

    test(
      'worker performs real HTTP without platform channel bindings',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final forms = <Map<String, String>>[];
        final subscription = server.listen((request) async {
          forms.add(
            Uri.splitQueryString(await utf8.decoder.bind(request).join()),
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'url': 'https://audio.example/live.mp3'}),
          );
          await request.response.close();
        });
        final runtime = IsolatedLxRuntime();
        addTearDown(() async {
          runtime.close();
          await server.close(force: true);
          await subscription.cancel();
        });
        await runtime.start(lxFixtureScript, name: 'http-worker');
        final result =
            await runtime.request('wy', 'musicUrl', {
                  'url': 'http://127.0.0.1:${server.port}/resolve',
                })
                as Map;
        expect(result['url'], 'https://audio.example/live.mp3');
        expect(forms.single['title'], '测试曲目');
      },
    );

    test(
      'unresolved promise times out and closed worker rejects new requests',
      () async {
        final runtime = IsolatedLxRuntime(timeout: const Duration(seconds: 2));
        addTearDown(runtime.close);
        await runtime.start(lxFixtureScript, name: 'timeout');
        await expectLater(
          runtime.request('wy', 'musicUrl', {'hang': true}),
          throwsA(isA<ApiFailure>()),
        );
        await expectLater(
          runtime.request('wy', 'musicUrl', {}),
          throwsA(isA<ApiFailure>()),
        );
      },
    );

    test(
      'finite synchronous script leaves the caller event loop responsive',
      () async {
        final runtime = IsolatedLxRuntime();
        addTearDown(runtime.close);
        await runtime.start(lxFixtureScript, name: 'busy');
        var completed = false;
        final pending = runtime.request('wy', 'musicUrl', {'busy': 300}).then((
          value,
        ) {
          completed = true;
          return value;
        });
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(completed, isFalse);
        expect((await pending as Map)['name'], 'busy');
      },
    );

    test(
      'closing resolves a pending request without waiting for its timeout',
      () async {
        final runtime = IsolatedLxRuntime();
        addTearDown(runtime.close);
        await runtime.start(lxFixtureScript, name: 'close');
        final pending = runtime.request('wy', 'musicUrl', {'hang': true});
        final check = expectLater(pending, throwsA(isA<ApiFailure>()));
        runtime.close();
        await check;
      },
    );
  }, skip: !Platform.isMacOS);
}
