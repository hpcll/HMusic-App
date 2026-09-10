import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/app/views/direct_settings_page.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/core/upgrade/app_update_badge.dart';
import 'package:hmusic/features/settings/models/settings_section.dart';
import 'package:hmusic/features/settings/view_models/settings_menu_view_model.dart';
import 'package:hmusic/features/settings/widgets/settings_menu.dart';
import 'package:hmusic/features/settings/widgets/settings_section_subpage.dart';

class _QuietBadge extends AppUpdateBadge {
  @override
  String build() => '';
}

void main() {
  testWidgets(
    'direct settings uses the shared layout and preserves advanced drafts across resize',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final width = ValueNotifier<double>(900);
      addTearDown(width.dispose);
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          appUpdateBadgeProvider.overrideWith(_QuietBadge.new),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      container
          .read(settingsMenuViewModelProvider.notifier)
          .open(SettingsSection.config);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HMusicTheme.light(),
            home: Scaffold(
              body: ValueListenableBuilder<double>(
                valueListenable: width,
                builder: (_, value, child) => Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: value, child: child),
                ),
                child: const DirectSettingsPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsMenu), findsOneWidget);
      await tester.ensureVisible(find.text('高级连接选项'));
      await tester.tap(find.text('高级连接选项'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '192.168.1.99');
      await tester.enterText(find.byType(TextField).last, 'L20A');
      width.value = 360;
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSectionSubpage), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        '192.168.1.99',
      );
      width.value = 900;
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller?.text,
        'L20A',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
