import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:hmusic/features/charts/data/charts_repository.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';
import 'package:hmusic/features/charts/widgets/charts_featured_lead.dart';
import 'package:hmusic/features/charts/widgets/charts_hero.dart';
import 'package:hmusic/features/charts/widgets/charts_section_row.dart';
import 'package:hmusic/features/charts/widgets/charts_wall.dart';

// 假仓库：本站 1 榜（分区应被判纯重复而隐藏）、网易云 2 榜（分区保留完整目录），
// 详情带 Top3（含 #1 封面）供 Hero 与预览取用，避开 apiClient → 平台通道。
class _FakeChartsRepository implements ChartsRepository {
  const _FakeChartsRepository();

  @override
  Future<List<Chart>> getCharts() async => const <Chart>[
    Chart(id: 'family-hot', name: '本站热歌榜', kind: 'family'),
    Chart(id: 'netease-hot', name: '云村飙升榜', kind: 'netease'),
    Chart(id: 'netease-new', name: '云村新歌榜', kind: 'netease'),
  ];

  @override
  Future<ChartDetail> getChart(String id) async => ChartDetail(
    id: id,
    name: id == 'family-hot' ? '本站热歌榜' : '云村飙升榜',
    kind: id == 'family-hot' ? 'family' : 'netease',
    entries: const <ChartEntry>[
      ChartEntry(
        rank: 1,
        title: '晴天',
        artist: '周杰伦',
        coverUrl: 'https://example.com/1.jpg',
      ),
      ChartEntry(rank: 2, title: '稻香', artist: '周杰伦'),
      ChartEntry(rank: 3, title: '七里香', artist: '周杰伦'),
    ],
  );

  @override
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex}) async =>
      throw UnimplementedError();
}

// 只在 initState 触发一次 load()，对齐真实 ChartsPage 的行为——
// 若写在 build/Consumer builder 里会每帧重调，++_generation 把预取回填判为旧代丢弃。
class _LoadOnce extends ConsumerStatefulWidget {
  const _LoadOnce();

  @override
  ConsumerState<_LoadOnce> createState() => _LoadOnceState();
}

class _LoadOnceState extends ConsumerState<_LoadOnce> {
  @override
  void initState() {
    super.initState();
    // microtask 包裹：避开 initState 内直接改 provider（对齐 ChartsPage.initState）。
    unawaited(
      Future<void>.microtask(
        () => ref.read(chartsViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const ChartsWall();
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chartsRepositoryProvider.overrideWithValue(
          const _FakeChartsRepository(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: _LoadOnce())),
    ),
  );
  // load() 经 microtask 触发 → 目录到达 → 预览预取（二段异步）逐条回填。
  // pumpAndSettle 推进到静止：骨架↔内容 180ms 淡化是有限动画，无无限循环，不会 hang。
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders view title, hero carousel and section rows', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('榜单'), findsOneWidget);
    // Hero 主推轮播存在（每来源取旗舰一张）。
    expect(find.byType(ChartsHeroCarousel), findsOneWidget);
    // 本站只有旗舰一张榜（纯重复分区隐藏），仅网易云（2 榜）保留分区行。
    expect(find.byType(ChartsSectionRow), findsOneWidget);
    // 分区标题不挂 chevron：卡带已陈列全部榜单，无下级目的地，箭头是假承诺。
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('hero shows source label and serif chart name', (tester) async {
    await _pump(tester);

    // Hero 卡底部渲染来源小字 + 衬线榜名（首张旗舰 = family）。
    expect(find.text('本站'), findsWidgets);
    expect(find.text('本站热歌榜'), findsWidgets);
  });

  testWidgets('wide layout swaps hero carousel for featured lead strip', (
    tester,
  ) async {
    // ≥860 走桌面分支：主打横滑带（每来源一张主打卡）替代全幅轮播。
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);

    // 两个来源各一张主打卡（1280 视口下两张 460 宽卡都可见）。
    expect(find.byType(ChartsFeaturedLead), findsNWidgets(2));
    expect(find.byType(ChartsHeroCarousel), findsNothing);
    // 主打卡渲染眉题（来源 · 每日更新）与 Top3 富文本行。
    expect(find.text('本站 · 每日更新'), findsOneWidget);
    expect(find.textContaining('晴天', findRichText: true), findsWidgets);
  });
}
