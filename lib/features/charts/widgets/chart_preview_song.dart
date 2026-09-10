import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../models/chart.dart';

// Top3 使用完整宽度展示歌名，歌手另起一行；命中高度随无障碍字号增长。
class ChartPreviewSong extends StatelessWidget {
  const ChartPreviewSong({required this.entry, this.onTap, super.key});

  final ChartEntry entry;
  final VoidCallback? onTap;

  static double heightFor(TextScaler scaler) => math.max(
    44,
    (10 + scaler.scale(13) * 1.3 + scaler.scale(12) * 1.3).ceilToDouble(),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: '${entry.title}，${entry.artist}',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          height: heightFor(MediaQuery.textScalerOf(context)),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text(
                  '${entry.rank}',
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 12,
                    fontWeight: entry.rank == 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: entry.rank == 1 ? palette.textStrong : palette.muted,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.artist.isEmpty ? '未知歌手' : entry.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
