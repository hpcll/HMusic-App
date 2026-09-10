import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/app/views/direct_settings_page.dart';
import 'package:hmusic/core/config/build_edition.dart';
import 'package:hmusic/core/direct/direct_providers.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/startup/app_opening.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/connection/models/connection_view_state.dart';
import 'package:hmusic/features/connection/view_models/connection_view_model.dart';
import 'package:hmusic/features/connection/views/connection_page.dart';

import '../../core/playback/support/direct_fixture.dart';

class _Connection extends ConnectionViewModel {
  int resumes = 0;
  @override
  ConnectionViewState build() =>
      const ConnectionViewState(discoverCompleted: true);
  @override
  Future<bool> resumeSaved() async {
    resumes++;
    return true;
  }

  @override
  Future<void> loadSavedAddress() async {}
  @override
  Future<void> discover() async {}
}

void main() {
  testWidgets(
    '从直连设置切回服务器会自动接续上次连接',
    (tester) async {
      final connection = _Connection();
      final direct = DirectFixture();
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          connectionViewModelProvider.overrideWith(() => connection),
          miDirectAccountRepositoryProvider.overrideWithValue(direct.account),
          directPlaybackRepositoryProvider.overrideWithValue(direct.playback),
        ],
      );
      container.read(appOpeningProvider).claim();
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: DirectSettingsPage()),
          ),
          GoRoute(
            path: '/connect',
            builder: (_, state) => ConnectionPage(
              autoResume: state.uri.queryParameters['switch'] != '1',
            ),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, _) => const Scaffold(body: Text('恢复服务器会话')),
          ),
        ],
      );
      try {
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
        final button = find.text('切换到服务器模式');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(connection.resumes, 1);
        expect(find.text('恢复服务器会话'), findsOneWidget);
        expect(container.read(playbackModeProvider), PlaybackMode.server);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        await direct.dispose();
      }
    },
    skip: BuildEdition.isStore,
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
