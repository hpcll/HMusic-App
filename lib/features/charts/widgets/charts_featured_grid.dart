import 'package:flutter/material.dart';

import '../models/chart.dart';
import 'charts_featured_lead.dart';

// 桌面把主推完整陈列在网格内，鼠标只需纵向浏览，无隐藏的横向卡带。
class ChartsFeaturedGrid extends StatelessWidget {
  const ChartsFeaturedGrid({
    required this.featured,
    required this.previews,
    required this.labelOf,
    required this.onOpen,
    super.key,
  });

  final List<Chart> featured;
  final Map<String, List<ChartEntry>?> previews;
  final String Function(String kind) labelOf;
  final void Function(Chart chart) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = ((constraints.maxWidth + 14) / (400 * scale + 14))
              .floor()
              .clamp(1, 2);
          final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              for (final chart in featured)
                SizedBox(
                  width: width,
                  child: ChartsFeaturedLead(
                    chart: chart,
                    entries: previews[chart.id] ?? const <ChartEntry>[],
                    sourceLabel: labelOf(chart.kind),
                    onOpen: () => onOpen(chart),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
