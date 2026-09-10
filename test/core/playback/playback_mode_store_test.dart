import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_store.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

void main() {
  late MemoryKeyValueStore preferences;
  setUp(() => preferences = MemoryKeyValueStore());

  test(
    'mode survives recreating the store and clear restores default',
    () async {
      final store = PlaybackModeStore(preferences: preferences);
      expect(await store.read(), PlaybackMode.server);
      await store.write(PlaybackMode.direct);
      expect(
        await PlaybackModeStore(preferences: preferences).read(),
        PlaybackMode.direct,
      );
      await store.clear();
      expect(await store.read(), PlaybackMode.server);
    },
  );

  test('mode writes preserve server configuration', () async {
    await preferences.setString('hmusic.serverBase', 'https://music.test');
    await PlaybackModeStore(
      preferences: preferences,
    ).write(PlaybackMode.direct);
    expect(
      await preferences.getString('hmusic.serverBase'),
      'https://music.test',
    );
  });
}
