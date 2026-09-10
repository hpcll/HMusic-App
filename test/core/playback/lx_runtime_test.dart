import 'dart:async';
import 'dart:io';

import 'package:flutter_js/javascriptcore/jscore_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/direct/music/lx_runtime.dart';
import 'package:hmusic/core/network/api_failure.dart';

import 'support/lx_fixture.dart';

void main() {
  group('native JSC LX bridge', () {
    test('native engine can evaluate the bundled bridge bootstrap', () async {
      final engine = JavascriptCoreRuntime();
      addTearDown(engine.dispose);
      final result = engine.evaluate(
        await File('assets/lx/runtime.js').readAsString(),
      );
      expect(result.isError, isFalse, reason: result.stringResult);
    });
    late LxFixtureAdapter adapter;
    late DirectMusicHttp http;
    late FlutterLxRuntime runtime;
    setUp(() {
      adapter = LxFixtureAdapter();
      http = DirectMusicHttp(adapter: adapter);
      runtime = FlutterLxRuntime(
        http,
        bootstrap: () => File('assets/lx/runtime.js').readAsString(),
      );
    });
    tearDown(() {
      runtime.close();
      http.close();
    });

    test('executes real JS with HTTP, Buffer, MD5, AES and timers', () async {
      expect(await runtime.start(lxFixtureScript, name: 'fixture'), {
        'wy': ['128k', '320k'],
      });
      final result =
          await runtime.request('wy', 'musicUrl', {
                'url': 'https://fixture.example/resolve',
                'delay': 10,
              })
              as Map;
      expect(result['digest'], '900150983cd24fb0d6963f7d28e17f72');
      expect(result['aes'], '69c4e0d86a7b0430d8cdb78070b4c55a');
      expect(result['text'], 'abc');
      expect(result['randomLength'], 16);
      expect(result['url'], 'https://audio.example/fixture.mp3');
      expect(result['status'], 200);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.headers['X-Lx-Fixture'], 'fixture');
      expect(
        adapter.requests.single.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(adapter.forms.single, {
        'digest': '900150983cd24fb0d6963f7d28e17f72',
        'title': '测试曲目',
      });
    });

    test(
      'rejected promises surface as sanitized errors and engine stays usable',
      () async {
        await runtime.start(lxFixtureScript, name: 'reject');
        await expectLater(
          runtime.request('wy', 'musicUrl', {'reject': true}),
          throwsA(isA<ApiFailure>()),
        );
        expect(
          (await runtime.request('wy', 'musicUrl', {}) as Map)['count'],
          1,
        );
      },
    );

    test(
      'closing cancels in-flight HTTP and resolves pending work with failure',
      () async {
        await runtime.start(lxFixtureScript, name: 'cancel');
        adapter.gate = Completer<void>();
        final pending = runtime.request('wy', 'musicUrl', {
          'url': 'https://fixture.example/pending',
        });
        final check = expectLater(pending, throwsA(isA<ApiFailure>()));
        while (adapter.requests.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        runtime.close();
        await check;
        await Future<void>.delayed(Duration.zero);
        expect(adapter.cancelled, isTrue);
      },
    );

    test('close during bootstrap never creates a late engine', () async {
      runtime.close();
      final gate = Completer<String>();
      runtime = FlutterLxRuntime(http, bootstrap: () => gate.future);
      final pending = runtime.start(lxFixtureScript, name: 'early close');
      final check = expectLater(pending, throwsA(isA<ApiFailure>()));
      runtime.close();
      gate.complete(await File('assets/lx/runtime.js').readAsString());
      await check;
    });
  }, skip: !Platform.isMacOS);
}
