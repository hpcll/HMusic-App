import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/views/direct_settings_page.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:hmusic/features/charts/models/chart_catalog.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';
import 'package:hmusic/features/charts/widgets/charts_wall.dart';
import 'package:hmusic/features/settings/widgets/sections/direct_options_section.dart';
import 'package:hmusic/features/settings/widgets/settings_menu.dart';
import 'package:integration_test/integration_test.dart';

import 'direct_web_verification_test.dart' as verification;
import 'support/direct_polish_harness.dart';
import 'support/native_test_report.dart';
import 'support/verification_harness.dart';

void main() {
  verification.main();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const report = NativeTestReport('direct-mode-polish');
  final details = <String, Object?>{
    'storage': 'memory-fixture',
    'upstream': 'public-live',
  };
  unawaited(
    binding.allTestsPassed.future.then(
      (passed) => report.write(passed ? 'passed' : 'failed', {
        ...details,
        'failures': binding.failureMethodsDetails
            .map((failure) => failure.toString())
            .toList(),
      }),
    ),
  );

  testWidgets('public charts and shared direct settings render on iPhone', (
    tester,
  ) async {
    await report.write('started', details);
    final harness = DirectPolishHarness();
    addTearDown(harness.dispose);
    await harness.init();
    await tester.pumpWidget(harness.app(const ChartsWall()));
    final vm = harness.container.read(chartsViewModelProvider.notifier);
    await pumpUntil(tester, vm.load(), timeout: const Duration(seconds: 90));
    final state = harness.container.read(chartsViewModelProvider);
    expect(state.charts, hasLength(17));
    expect(state.previewErrors, isEmpty);
    final repository = harness.container.read(chartsRepositoryProvider);
    final counts = <String, int>{};
    for (final chart in discoveryCharts(state.charts, 'featured')) {
      final detail = await pumpUntil(tester, repository.getChart(chart.id));
      counts[chart.kind] = detail.entries.length;
      if (chart.kind != 'family') expect(detail.entries, hasLength(50));
    }
    details['chartEntryCounts'] = counts;
    await harness.screenshot(tester, 'direct-discovery');
    await pumpUntil(
      tester,
      vm.selectSource('qq'),
      timeout: const Duration(seconds: 60),
    );
    expect(
      harness.container.read(chartsViewModelProvider).discovery,
      hasLength(3),
    );
    await harness.screenshot(tester, 'direct-qq-charts');
    details['platformFilterWorks'] = true;
    await report.write('running', details);

    await tester.pumpWidget(harness.app(const DirectSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsMenu), findsOneWidget);
    expect(find.text('账号与设备'), findsOneWidget);
    expect(find.text('本机音源'), findsOneWidget);
    await harness.screenshot(tester, 'direct-settings');
    await tester.ensureVisible(find.text('直连配置'));
    await tester.tap(find.text('直连配置'));
    await tester.pumpAndSettle();
    expect(find.byType(DirectOptionsSection), findsOneWidget);
    await harness.screenshot(tester, 'direct-playback-options');
    await tester.ensureVisible(find.text('高级连接选项'));
    await tester.tap(find.text('高级连接选项'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('补充音箱兼容型号'));
    await harness.screenshot(tester, 'direct-speaker-options');
    details['sharedSettingsAndSpeakerOptions'] = true;
    expect(tester.takeException(), isNull);
  });
}
