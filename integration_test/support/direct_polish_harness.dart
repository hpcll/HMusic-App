import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/direct/direct_providers.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/core/upgrade/app_update_badge.dart';
import 'package:hmusic/features/settings/data/direct_settings_repository.dart';
import 'package:integration_test/integration_test.dart';

import 'native_test_report.dart';

class _QuietBadge extends AppUpdateBadge {
  @override
  String build() => '';
}

class DirectPolishHarness {
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      appUpdateBadgeProvider.overrideWith(_QuietBadge.new),
      directSettingsRepositoryProvider.overrideWith(
        (ref) => DirectSettingsRepository(ref.watch(directLocalStoreProvider)),
      ),
    ],
  );

  Future<void> init() async {
    await container
        .read(playbackModeProvider.notifier)
        .select(PlaybackMode.direct);
  }

  Widget app(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: HMusicTheme.light(),
      home: Scaffold(body: child),
    ),
  );

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    final bytes = await binding.takeScreenshot(name);
    await File(
      '${NativeTestReport.outputDirectory}/hmusic-$name.png',
    ).writeAsBytes(bytes, flush: true);
  }

  void dispose() => container.dispose();
}
