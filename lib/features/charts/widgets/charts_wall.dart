import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/chart.dart';
import '../models/charts_view_state.dart';
import '../view_models/charts_view_model.dart';
import 'charts_featured_lead.dart';
import 'charts_hero.dart';
import 'charts_section_row.dart';

// 榜单入口墙：刊物式页头（大标题 + 副标题）+ 主打区 + 按来源分组的横滑卡带。
// 主打区分屏宽两种形态：桌面用头版主打卡（暖纸 panel、1:1 封面原比例、Top3 预览），
// 窄屏用 Apple Music「广播」式全幅轮播。视觉守 HMusic 纪律（暖纸/墨字/衬线/细边）。
class ChartsWall extends ConsumerWidget {
  const ChartsWall({super.key});

  static const List<(String kind, String label)> _groups = <(String, String)>[
    ('family', '本站'),
    ('netease', '网易云音乐'),
    ('qq', 'QQ音乐'),
    ('apple', 'Apple Music'),
  ];

  static String _labelOf(String kind) {
    for (final (k, label) in _groups) {
      if (k == kind) return label;
    }
    return kind;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(chartsViewModelProvider);
    final notifier = ref.read(chartsViewModelProvider.notifier);

    if (state.status == ChartsStatus.loading && state.charts.isEmpty) {
      return const _Centered(child: CircularProgressIndicator());
    }
    if (state.status == ChartsStatus.error && state.charts.isEmpty) {
      return _Centered(
        child: Text(
          state.errorMessage ?? '榜单加载失败',
          style: TextStyle(color: palette.muted),
        ),
      );
    }

    final featured = _featured(state.charts);
    // 桌面宽屏用「头版主打」卡（1:1 封面原比例 + Top3），窄屏用全幅轮播——
    // 与 app_shell 同一 860 断点。
    final wide = MediaQuery.sizeOf(context).width >= 860;

    return ListView(
      // 顶/底累加环境 padding：玻璃顶栏与悬浮 mini/dock 之下让位（scroll-under）。
      padding: EdgeInsets.only(
        top: 24 + MediaQuery.paddingOf(context).top,
        bottom: 32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        // 刊物式页头：大标题 + 一行 muted 副标题，标题不再孤零零贴着窗口顶。
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ViewTitle('榜单'),
              const SizedBox(height: 6),
              Text(
                '本站与全网热榜 · 每日更新',
                style: TextStyle(fontSize: 13.5, color: palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (featured.isNotEmpty) ...<Widget>[
          if (wide)
            // 主打横滑带：四来源各一张主打卡，横滑 + 末尾露边（peek），
            // 与下方分组卡带同一套交互语法（对齐 Apple Music「广播」Hero 的骨架）。
            SizedBox(
              height: ChartsFeaturedLead.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final chart = featured[i];
                  return SizedBox(
                    width: ChartsFeaturedLead.width,
                    child: ChartsFeaturedLead(
                      chart: chart,
                      entries: state.previews[chart.id] ?? const <ChartEntry>[],
                      sourceLabel: _labelOf(chart.kind),
                      onOpen: () => notifier.openChart(chart),
                    ),
                  );
                },
              ),
            )
          else
            ChartsHeroCarousel(
              featured: featured,
              covers: _covers(state),
              labelOf: _labelOf,
              onOpen: notifier.openChart,
            ),
          const SizedBox(height: 30),
        ],
        for (final (kind, label) in _groups)
          if (_sectionVisible(state, kind))
            _section(state, notifier, kind, label),
      ],
    );
  }

  // 纯重复分区不渲染：某来源只有旗舰一张榜（已上主打区）时，分区里那张卡
  // 与主打卡信息 100% 相同，零新信息还像布局坏了。有第二张榜起分区自动回来，
  // 且保持完整目录（旗舰照常在列，混在多卡里不显重复——Apple Music 同款做法）。
  bool _sectionVisible(ChartsViewState state, String kind) =>
      state.charts.where((c) => c.kind == kind).length > 1;

  // 主推：每个来源组取第一张作旗舰，横滑轮播（对齐 Apple Hero 每类一张主推）。
  List<Chart> _featured(List<Chart> charts) {
    final result = <Chart>[];
    for (final (kind, _) in _groups) {
      final first = charts
          .where((c) => c.kind == kind)
          .cast<Chart?>()
          .firstWhere((c) => c != null, orElse: () => null);
      if (first != null) result.add(first);
    }
    return result;
  }

  // chartId → #1 封面 url（取预览首条）。缺则 Hero 走深色占位。
  Map<String, String?> _covers(ChartsViewState state) {
    final covers = <String, String?>{};
    state.previews.forEach((id, entries) {
      covers[id] = (entries != null && entries.isNotEmpty)
          ? entries.first.coverUrl
          : null;
    });
    return covers;
  }

  Widget _section(
    ChartsViewState state,
    ChartsViewModel notifier,
    String kind,
    String label,
  ) {
    final items = state.charts.where((c) => c.kind == kind).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: ChartsSectionRow(
        label: label,
        charts: items,
        previews: state.previews,
        onOpen: notifier.openChart,
        onPlayEntry: notifier.play,
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(child: child),
    );
  }
}
