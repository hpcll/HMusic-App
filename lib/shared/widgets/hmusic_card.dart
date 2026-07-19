import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../../app/theme/hmusic_radii.dart';

// 卡片原子，对齐 web .card：panel 底 / 1px line 边 / padding 20 / 克制阴影；
// 圆角走全站柔化 token（HMusicRadii.card）。
// onTap 非空时作为可点卡片（榜单卡、歌单卡），hover/press 由 InkWell 反馈。
class HMusicCard extends StatelessWidget {
  const HMusicCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(HMusicRadii.card);
    return Material(
      color: palette.panel,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: palette.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
