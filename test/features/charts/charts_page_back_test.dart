import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:hmusic/features/charts/data/charts_repository.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';
import 'package:hmusic/features/charts/views/charts_page.dart';

// 最小假仓库：单榜 + 空曲目详情，避开 apiClient → 平台通道。
class _FakeChartsRepository implements ChartsRepository {
  const _FakeChartsRepository();

  @override
  Future<List<Chart>> getCharts() async => const <Chart>[
    Chart(id: 'hot', name: '云村飙升榜', kind: 'netease'),
  ];

  @override
  Future<ChartDetail> getChart(String id) async =>
      const ChartDetail(id: 'hot', name: '云村飙升榜', kind: 'netease');

  @override
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex}) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('榜单详情：系统返回收回卡片墙；墙面一级不再拦截', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chartsRepositoryProvider.overrideWithValue(
            const _FakeChartsRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ChartsPage())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChartsPage)),
      listen: false,
    );
    final notifier = container.read(chartsViewModelProvider.notifier);
    await notifier.openChart(
      const Chart(id: 'hot', name: '云村飙升榜', kind: 'netease'),
    );
    await tester.pumpAndSettle();
    expect(container.read(chartsViewModelProvider).isWall, isFalse);
    expect(find.text('返回'), findsOneWidget);

    // 系统返回（与 go_router popRoute 同走 maybePop → PopScope 链）。
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(container.read(chartsViewModelProvider).isWall, isTrue);
    expect(find.text('返回'), findsNothing);
  });
}
