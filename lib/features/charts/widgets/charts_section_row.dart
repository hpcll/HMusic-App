import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/chart.dart';
import 'chart_card.dart';

// 分区横滑行，结构借鉴 Apple Music 风格电台：小节标题 + 横向卡片带（末尾自然露边）。
// 标题不带 chevron——卡带已陈列该来源全部榜单，分区层级没有「更多」目的地，
// 挂箭头是有指无路的假承诺（Apple Music 的「›」都真的可点进下级页）。
// 复用现有 ChartCard（守 HMusic 内容风：panel 底 / 细边 / 衬线榜名），只套固定宽度做横滑。
class ChartsSectionRow extends StatelessWidget {
  const ChartsSectionRow({
    required this.label,
    required this.charts,
    required this.previews,
    required this.onOpen,
    required this.onPlayEntry,
    super.key,
  });

  final String label;
  final List<Chart> charts;
  final Map<String, List<ChartEntry>?> previews;
  final void Function(Chart chart) onOpen;
  final void Function(ChartEntry entry) onPlayEntry;

  static const double _cardWidth = 236;
  // 卡内容累计高：封面 44 + 间隔 10 + 预览 78 + 卡上下 padding 14×2 = 160，
  // 取 162 留余量，避免横滑行里 ChartCard 的 Column 竖向溢出。
  static const double _cardHeight = 162;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (charts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'NotoSerifSC',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.textStrong,
            ),
          ),
        ),
        // 卡带是像素级等高包络（_cardHeight/预览 78），无障碍大字号下会精确溢出：
        // 字号钳到 1.2 倍保横滑卡排版（页头/详情等自由布局不受限），包络同步随
        // 钳后倍率等比伸缩（ChartCard 预览区同曲线），任何字号档都不溢出。
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: SizedBox(
            height:
                _cardHeight *
                MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.2).scale(1),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // 首尾留 16 padding，卡带自然在右侧露边（peek），暗示可横滑。
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: charts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final chart = charts[i];
                return SizedBox(
                  width: _cardWidth,
                  child: ChartCard(
                    chart: chart,
                    preview: previews[chart.id],
                    pending: !previews.containsKey(chart.id),
                    onOpen: () => onOpen(chart),
                    onPlayEntry: onPlayEntry,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
