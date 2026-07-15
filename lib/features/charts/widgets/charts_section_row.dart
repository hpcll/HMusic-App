import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/chart.dart';
import 'chart_card.dart';

// 分区横滑行，结构借鉴 Apple Music「风格电台 ›」：小节标题带 chevron + 横向卡片带（末尾自然露边）。
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
  // 卡内容累计高：封面 44 + 间隔 10 + 预览 76 + 间隔 6 + 「查看全部」行 ≈20 + 卡上下 padding 14×2
  // = 184，取 188 留余量，避免横滑行里 ChartCard 的 Column 竖向溢出。
  static const double _cardHeight = 188;

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
          child: Row(
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: palette.textStrong,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.muted),
            ],
          ),
        ),
        SizedBox(
          height: _cardHeight,
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
      ],
    );
  }
}
