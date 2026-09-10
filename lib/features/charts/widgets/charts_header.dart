import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/view_title.dart';

// 手机找歌页的吸顶搜索入口；文字与包络一起增长，不限制系统字号。
class ChartsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const ChartsHeaderDelegate({
    required this.topPadding,
    required this.textScaler,
  });

  final double topPadding;
  final TextScaler textScaler;

  double get _titleHeight =>
      textScaler.scale(22) * 1.2 + 6 + textScaler.scale(13.5) * 1.4;
  double get _entryHeight => math.max(44, 16 + textScaler.scale(14.5) * 1.4);

  @override
  double get maxExtent =>
      topPadding + 24 + _titleHeight + 16 + _entryHeight + 12;

  @override
  double get minExtent => topPadding + 8 + _entryHeight + 12;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.palette;
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return ClipRect(
      child: Stack(
        children: <Widget>[
          Positioned(
            top: topPadding + 24 - shrinkOffset,
            left: 16,
            right: 16,
            child: Opacity(
              opacity: (1 - progress * 1.6).clamp(0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ViewTitle('找歌'),
                  const SizedBox(height: 6),
                  Text(
                    '常听回顾，热门发现',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: _SearchEntry(pinProgress: progress, height: _entryHeight),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(ChartsHeaderDelegate oldDelegate) =>
      oldDelegate.topPadding != topPadding ||
      oldDelegate.textScaler != textScaler;
}

// 这是导航入口，不提前创建 TextField 或抢焦点；所有宽度共用壳的路由规则。
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.pinProgress, required this.height});

  final double pinProgress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      button: true,
      label: '搜索歌曲或歌手',
      child: PressableScale(
        onTap: () {
          if (usesBottomNavigation(MediaQuery.sizeOf(context).width)) {
            unawaited(context.push<void>('/search'));
          } else {
            context.go('/search-tab');
          }
        },
        child: Stack(
          children: <Widget>[
            AdaptiveGlassSurface(
              quality: resolveGlassQuality(context),
              padding: EdgeInsets.zero,
              borderRadius: radius,
              shadow: false,
              hairline: false,
              child: SizedBox(height: height, width: double.infinity),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: (1 - pinProgress).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.panelSecondary,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded, size: 20, color: palette.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '搜索歌曲或歌手',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: palette.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
