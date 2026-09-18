import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/direct/music/isolated_lx_runtime.dart';
import 'package:hmusic/core/direct/music/lx_javascript_engine.dart';
import 'package:hmusic/core/direct/music/lx_runtime.dart';
import 'package:integration_test/integration_test.dart';

import '../test/core/playback/support/lx_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android QuickJS accepts the LX bootstrap and initialization',
    (tester) async {
      final engine = createLxJavascriptEngine();
      addTearDown(engine.dispose);
      final events = <Map<String, Object?>>[];
      engine.onMessage('HMusicLx', (Object? event) {
        if (event is Map<String, Object?>) events.add(event);
        return null;
      });
      for (final code in [
        await rootBundle.loadString('assets/lx/runtime.js'),
        '__hmusicStart({name: "native-fixture"});',
        lxFixtureScript,
      ]) {
        final result = engine.evaluate(code);
        expect(result.isError, isFalse, reason: result.stringResult);
        engine.executePendingJob();
      }
      expect(events.where((event) => event['type'] == 'init'), hasLength(1));
      expect(
        engine.evaluate('new ArrayBuffer(80 * 1024 * 1024)').isError,
        isTrue,
      );
      expect(engine.evaluate('21 * 2').stringResult, '42');
    },
    skip: !Platform.isAndroid,
  );

  testWidgets('native LX runs HTTP, crypto and asynchronous callbacks', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final http = DirectMusicHttp(adapter: LxFixtureAdapter());
    final runtime = FlutterLxRuntime(http);
    addTearDown(() {
      runtime.close();
      http.close();
    });
    expect(await runtime.start(lxFixtureScript, name: 'native-fixture'), {
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
    expect(result['url'], 'https://audio.example/fixture.mp3');
  });

  testWidgets('isolated LX initializes and returns a result on the device', (
    tester,
  ) async {
    final runtime = IsolatedLxRuntime();
    addTearDown(runtime.close);
    expect(await runtime.start(lxFixtureScript, name: 'isolated-fixture'), {
      'wy': ['128k', '320k'],
    });
    expect(
      (await runtime.request('wy', 'musicUrl', {}) as Map)['name'],
      'isolated-fixture',
    );
  });
}
