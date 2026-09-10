import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/config/build_edition.dart';
import 'package:hmusic/core/direct/music/direct_lx_sources.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/direct/storage/direct_local_store.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/playback/playback_mode_store.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

void main() {
  group('StoreEdition direct boundary', () {
    test(
      'stored direct selection restores Server and cannot be re-enabled',
      () async {
        final preferences = MemoryKeyValueStore();
        await PlaybackModeStore(
          preferences: preferences,
        ).write(PlaybackMode.direct);
        final container = ProviderContainer(
          overrides: [keyValueStoreProvider.overrideWithValue(preferences)],
        );
        addTearDown(container.dispose);
        final mode = container.read(playbackModeProvider.notifier);
        expect(await mode.restore(), PlaybackMode.server);
        await expectLater(
          mode.select(PlaybackMode.direct),
          throwsA(isA<ApiFailure>()),
        );
        expect(container.read(playbackModeProvider), PlaybackMode.server);
      },
    );

    test(
      'script save and execution stay disabled even through repositories',
      () async {
        final http = DirectMusicHttp();
        final sources = DirectLxSources(
          DirectLocalStore(MemoryKeyValueStore()),
          http,
        );
        addTearDown(() {
          sources.close();
          http.close();
        });
        await expectLater(
          sources.save({'id': 'test', 'code': 'void 0;'}),
          throwsA(isA<ApiFailure>()),
        );
        await expectLater(
          sources.resolve('wy', 'musicUrl', {}),
          throwsA(isA<ApiFailure>()),
        );
        expect(await sources.list(), isEmpty);
      },
    );
  }, skip: !BuildEdition.isStore);
}
