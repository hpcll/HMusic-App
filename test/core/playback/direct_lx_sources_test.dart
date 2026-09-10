import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_lx_sources.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/direct/music/lx_runtime.dart';
import 'package:hmusic/core/direct/storage/direct_local_store.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

const _plugin = r'''
lx.on('request', async ({info}) => {
  if (info.hang) return new Promise(() => {});
  if (info.type === '320k') throw new Error('fixture quality unavailable');
  return 'https://audio.example/' + info.type + '.mp3';
});
lx.send('inited', {status: true, sources: {
  wy: {actions: ['musicUrl'], qualitys: ['128k', '320k']},
}});
''';

void main() {
  group('direct sources with native runtime', () {
    late DirectLxSources sources;
    late DirectMusicHttp http;
    late List<LxRuntime> created;
    setUp(() {
      created = [];
      http = DirectMusicHttp();
      sources = DirectLxSources(
        DirectLocalStore(MemoryKeyValueStore()),
        http,
        createRuntime: () {
          final runtime = FlutterLxRuntime(
            http,
            bootstrap: () => File('assets/lx/runtime.js').readAsString(),
          );
          created.add(runtime);
          return runtime;
        },
      );
    });
    tearDown(() {
      sources.close();
      http.close();
    });

    Future<void> save(String id, String code) =>
        sources.save({'id': id, 'name': id, 'code': code, 'enabled': true});

    test(
      'quality fallback runs the actual plugin and caches its initialized runtime',
      () async {
        await save('a', _plugin);
        expect(
          await sources.resolve('wy', 'musicUrl', {'type': '320k'}),
          'https://audio.example/128k.mp3',
        );
        expect(await sources.test('a'), contains('wy'));
        expect(created, hasLength(1));
        expect(sources.health['a'], 'ok');
      },
    );

    test(
      'one total deadline bounds all enabled plugins and closes the timed-out runtime',
      () async {
        for (final id in ['a', 'b', 'c']) {
          await save(id, _plugin);
        }
        final watch = Stopwatch()..start();
        await expectLater(
          sources.resolve(
            'wy',
            'musicUrl',
            {'hang': true},
            deadline: DateTime.now().add(const Duration(milliseconds: 200)),
          ),
          throwsA(isA<ApiFailure>()),
        );
        expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
        expect(created, hasLength(1));
        await expectLater(
          created.single.request('wy', 'musicUrl', {}),
          throwsA(isA<ApiFailure>()),
        );
      },
    );

    test('首个插件地址不可播时继续尝试下一个插件', () async {
      await save('a', _plugin);
      await save('b', _plugin.replaceAll('audio.example', 'second.example'));
      final result = await sources.resolve(
        'wy',
        'musicUrl',
        {'type': '320k'},
        validate: (value) async {
          if ('$value'.contains('audio.example')) {
            throw const ApiFailure(
              kind: ApiFailureKind.invalidResponse,
              message: '音频被拒绝',
              statusCode: 403,
            );
          }
        },
      );
      expect(result, 'https://second.example/128k.mp3');
      expect(sources.health, {'a': 'failed', 'b': 'ok'});
    });

    test('切模式关闭音源后迟到的音频验证不能恢复旧结果', () async {
      await save('a', _plugin);
      final entered = Completer<void>(), gate = Completer<void>();
      final result = sources.resolve(
        'wy',
        'musicUrl',
        {'type': '128k'},
        validate: (_) async {
          entered.complete();
          await gate.future;
        },
      );
      final check = expectLater(
        result,
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.code,
            'code',
            'DIRECT_SOURCE_CHANGED',
          ),
        ),
      );
      await entered.future;
      sources.close();
      gate.complete();
      await check;
      expect(sources.health, isEmpty);
    });

    test(
      'close cancels loading and queued tests without restoring stale health',
      () async {
        await save('a', 'const missingInitialization = true;');
        final first = sources.test('a');
        final check = expectLater(first, throwsA(isA<ApiFailure>()));
        final queued = expectLater(
          sources.test('a'),
          throwsA(isA<ApiFailure>()),
        );
        while (created.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        sources.close();
        await Future.wait([check, queued]);
        expect(sources.health, isEmpty);
        expect(created, hasLength(1));
      },
    );
  }, skip: !Platform.isMacOS);
}
