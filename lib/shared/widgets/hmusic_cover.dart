import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';

// 全站封面原子：方形封面 + 网络图，缺图/加载失败回退音符占位。
// 对齐 web .track-cover / .chart-card-cover（panel-2 底 + line-soft 细边 + 居中 ♪）。
class HMusicCover extends StatelessWidget {
  const HMusicCover({
    required this.url,
    this.size = 44,
    this.radius = 6,
    this.iconSize = 18,
    super.key,
  });

  final String? url;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final border = BorderRadius.circular(radius);
    final fallback = Center(
      child: Icon(
        Icons.music_note_rounded,
        size: iconSize,
        color: palette.muted,
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.panelSecondary,
        borderRadius: border,
        border: Border.all(color: palette.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            ),
    );
  }
}
