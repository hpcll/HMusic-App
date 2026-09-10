import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/chart.dart';
import 'chart_card.dart';

// 手机保留横向浏览；内容区充足时直接陈列网格，桌面无需寻找隐藏的横向滚动。
class ChartsSectionRow extends StatelessWidget {
  const ChartsSectionRow({
    required this.label,
    required this.charts,
    required this.previews,
    required this.onOpen,
    required this.onPlayEntry,
    this.description,
    this.previewErrors = const <String, String>{},
    this.onRetry,
    this.horizontalOnMobile = true,
    super.key,
  });

  final String label;
  final List<Chart> charts;
  final Map<String, List<ChartEntry>?> previews;
  final void Function(Chart chart) onOpen;
  final void Function(ChartEntry entry) onPlayEntry;
  final String? description;
  final Map<String, String> previewErrors;
  final void Function(Chart chart)? onRetry;
  final bool horizontalOnMobile;

  @override
  Widget build(BuildContext context) {
    if (charts.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final scale = scaler.scale(14) / 14;
        final height = ChartCard.heightFor(scaler);
        final available = math.max(0.0, constraints.maxWidth - 32);
        final grid = !horizontalOnMobile || constraints.maxWidth >= 560;
        final columns = ((available + 12) / (260 * scale + 12)).floor().clamp(
          1,
          math.min(charts.length, 4),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textStrong,
                      ),
                    ),
                    if (description != null) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (grid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final chart in charts)
                      SizedBox(
                        width: (available - 12 * (columns - 1)) / columns,
                        height: height,
                        child: _card(chart),
                      ),
                  ],
                ),
              )
            else
              SizedBox(
                height: height,
                child: ListView.separated(
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: charts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: math.min(280 * scale, math.max(160, available - 16)),
                    child: _card(charts[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _card(Chart chart) => ChartCard(
    chart: chart,
    preview: previews[chart.id],
    pending: !previews.containsKey(chart.id),
    onOpen: () => onOpen(chart),
    onPlayEntry: onPlayEntry,
    errorMessage: previewErrors[chart.id],
    onRetry: onRetry == null ? null : () => onRetry!(chart),
  );
}
