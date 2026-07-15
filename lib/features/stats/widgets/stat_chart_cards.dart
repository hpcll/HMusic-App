import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../models/stats.dart';
import 'hour_bars_painter.dart';
import 'source_donut_painter.dart';
import 'trend_line_painter.dart';

// 图表卡外框：标题 + 内容（+ 可选底部坐标轴刻度）。
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.axis});

  final String title;
  final Widget child;
  final List<String>? axis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: palette.textStrong,
            ),
          ),
          const SizedBox(height: 14),
          child,
          if (axis != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final label in axis!)
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TrendCard extends StatelessWidget {
  const TrendCard({required this.daily, super.key});

  final List<TrendPoint> daily;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mid = daily.isEmpty ? '' : daily[daily.length ~/ 2].date;
    return _ChartCard(
      title: '听歌趋势 · 近 30 天',
      axis: <String>[
        daily.isEmpty ? '' : daily.first.date,
        mid,
        daily.isEmpty ? '' : daily.last.date,
      ],
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          size: Size.infinite,
          painter: TrendLinePainter(points: daily, ink: palette.textStrong),
        ),
      ),
    );
  }
}

class HoursCard extends StatelessWidget {
  const HoursCard({required this.hours, super.key});

  final List<HourPoint> hours;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _ChartCard(
      title: '听歌时段 · 全天分布',
      axis: const <String>['0 点', '6 点', '12 点', '18 点', '23 点'],
      child: SizedBox(
        height: 140,
        child: CustomPaint(
          size: Size.infinite,
          painter: HourBarsPainter(
            hours: hours,
            bar: palette.mutedStrong,
            peak: palette.textStrong,
          ),
        ),
      ),
    );
  }
}

class SourcesCard extends StatelessWidget {
  const SourcesCard({required this.sources, super.key});

  final List<SourceSlice> sources;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (sources.isEmpty) return const SizedBox.shrink();
    return _ChartCard(
      title: '来源平台分布',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: SourceDonutPainter(
                slices: sources,
                ink: palette.textStrong,
                muted: palette.mutedStrong,
                baseRing: palette.lineSoft,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < sources.length; i++)
                  _LegendRow(slice: sources[i], index: i),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.index});

  final SourceSlice slice;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = sourceLegendStyle(
      index,
      palette.textStrong,
      palette.mutedStrong,
    );
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: style.alpha),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: palette.textStrong),
            ),
          ),
          Text(
            '${slice.count} · ${slice.percent}%',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
