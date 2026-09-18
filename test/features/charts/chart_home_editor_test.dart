import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/charts/view_models/chart_home_preferences_view_model.dart';
import 'package:hmusic/features/charts/widgets/chart_home_editor.dart';

import 'chart_home_preferences_test.dart' show charts;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('editor hide/reorder/save/cancel at 360px and ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(chartHomePreferencesProvider.notifier).restore();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HMusicTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showChartHomeEditor(context, charts),
                  child: const Text('管理'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('管理'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(
        tester.widget<Switch>(find.byType(Switch).at(1)).onChanged,
        isNull,
      );
      expect(find.textContaining('至少保留一项'), findsOneWidget);
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorder(1, 0);
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved = container.read(chartHomePreferencesProvider);
      expect(saved.visibility['sp'], isFalse);
      expect(saved.order.first, 'wy');
      await tester.tap(find.text('管理'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复默认'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(container.read(chartHomePreferencesProvider), same(saved));
      expect(tester.takeException(), isNull);
    });
  }
}
