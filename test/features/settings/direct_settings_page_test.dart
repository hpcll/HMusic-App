import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/app/views/direct_settings_page.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

void main() {
  testWidgets(
    'player settings hide accounts and speaker options at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          clientPlaybackCapabilitiesProvider.overrideWithValue(
            const ClientPlaybackCapabilities(supportsLocalPlayback: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.player);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HMusicTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.7)),
              child: child!,
            ),
            home: const Scaffold(body: DirectSettingsPage(localOnly: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本机音源'), findsOneWidget);
      expect(find.text('小米账号'), findsNothing);
      expect(find.text('播放设备'), findsNothing);
      expect(find.text('服务器下载'), findsNothing);
      expect(find.text('退出登录'), findsNothing);
      await tester.tap(find.text('播放偏好').last);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
      expect(find.text('音箱播放'), findsNothing);
      expect(find.text('高级连接选项'), findsNothing);
      expect(find.text('保存播放偏好'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct settings shows supported local capabilities and large-text options',
    (tester) async {
      tester.view.physicalSize = const Size(360, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HMusicTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.7)),
              child: child!,
            ),
            home: const Scaffold(body: DirectSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本机音源'), findsOneWidget);
      expect(find.text('下载管理'), findsNothing);
      expect(find.text('Spotify'), findsNothing);
      await tester.tap(find.text('直连配置'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
}
