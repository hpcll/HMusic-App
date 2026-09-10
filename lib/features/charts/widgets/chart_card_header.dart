import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../models/chart.dart';
import '../models/chart_catalog.dart';

class ChartCardHeader extends StatelessWidget {
  const ChartCardHeader({required this.chart, this.cover, super.key});

  final Chart chart;
  final String? cover;

  static double heightFor(TextScaler scaler) => math.max(
    48,
    (scaler.scale(11) * 1.4 + 4 + scaler.scale(17) * 1.3 * 2).ceilToDouble(),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightFor(MediaQuery.textScalerOf(context)),
      child: Row(
        children: <Widget>[
          HMusicCover(url: cover, size: 48, radius: 7, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  chartSourceLabel(chart),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chart.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: context.palette.textStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
