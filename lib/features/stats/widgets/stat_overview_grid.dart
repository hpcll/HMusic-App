import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../models/stats.dart';

// 概览四数字卡，对齐 web .stat-grid/.stat-bignum：衬线大数字 + 标签 + 近30天增量。
// 宽屏四列、窄屏两列。
class StatOverviewGrid extends StatelessWidget {
  const StatOverviewGrid({
    required this.overview,
    required this.last30d,
    super.key,
  });

  final StatOverview overview;
  final StatOverview last30d;

  @override
  Widget build(BuildContext context) {
    final cards = <({String label, int value, int delta})>[
      (label: '累计播放', value: overview.totalPlays, delta: last30d.totalPlays),
      (label: '曲目数', value: overview.uniqueTracks, delta: last30d.uniqueTracks),
      (
        label: '艺术家',
        value: overview.uniqueArtists,
        delta: last30d.uniqueArtists,
      ),
      (label: '活跃天数', value: overview.activeDays, delta: last30d.activeDays),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final card in cards)
              SizedBox(
                width: width,
                child: _BigNum(
                  label: card.label,
                  value: card.value,
                  delta: card.delta,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BigNum extends StatelessWidget {
  const _BigNum({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final int value;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HMusicCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'NotoSerifSC',
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: palette.textStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.96,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '近30天 +$delta',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
