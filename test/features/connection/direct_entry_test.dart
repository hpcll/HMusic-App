import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/config/build_edition.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/playback/playback_mode_store.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/connection/models/connection_view_state.dart';
import 'package:hmusic/features/connection/view_models/connection_view_model.dart';
import 'package:hmusic/features/connection/views/connection_page.dart';

class _Connection extends ConnectionViewModel {
  int restores = 0, scans = 0;
  @override
  ConnectionViewState build() =>
      const ConnectionViewState(discoverCompleted: true);
  @override
  Future<void> loadSavedAddress() async {
    restores++;
  }

  @override
  Future<bool> resumeSaved() async {
    restores++;
    return false;
  }

  @override
  Future<void> discover() async {
    scans++;
  }
}

void main() {
  Future<({ProviderContainer container, _Connection connection})> pump(
    WidgetTester tester, {
    bool direct = false,
    bool autoResume = false,
  }) async {
    final preferences = MemoryKeyValueStore(), connection = _Connection();
    if (direct) {
      await PlaybackModeStore(
        preferences: preferences,
      ).write(PlaybackMode.direct);
    }
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(preferences),
        connectionViewModelProvider.overrideWith(() => connection),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/connect',
      routes: [
        GoRoute(
          path: '/connect',
          builder: (_, _) => ConnectionPage(autoResume: autoResume),
        ),
        GoRoute(
          path: '/direct/login',
          builder: (_, _) => const Scaffold(body: Text('小米登录入口')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: HMusicTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, connection: connection);
  }

  testWidgets(
    'persisted direct mode reaches Xiaomi login without restoring or scanning Server',
    (tester) async {
      final fixture = await pump(tester, direct: true, autoResume: true);
      expect(find.text('小米登录入口'), findsOneWidget);
      expect(fixture.connection.restores, 0);
      expect(fixture.connection.scans, 0);
    },
    skip: BuildEdition.isStore,
  );

  testWidgets(
    'connection page can enter direct mode without a Server',
    (tester) async {
      final fixture = await pump(tester);
      final entry = find.text('无需服务器，使用直连模式');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(fixture.container.read(playbackModeProvider), PlaybackMode.direct);
      expect(find.text('小米登录入口'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: BuildEdition.isStore,
  );

  testWidgets('StoreEdition omits the direct mode entry', (tester) async {
    await pump(tester);
    expect(find.text('无需服务器，使用直连模式'), findsNothing);
  }, skip: !BuildEdition.isStore);
}
