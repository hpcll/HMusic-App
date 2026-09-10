import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/layout/shell_metrics.dart';
import 'bottom_nav_item.dart';
import 'bottom_nav_row.dart';
import 'navigation_destinations.dart';

// 选中图标沿同一轨迹移动，其余标签淡出；避免两枚选中图标交叉淡化的重影。
class BottomNavTransition extends StatelessWidget {
  const BottomNavTransition({
    required this.shell,
    required this.progress,
    required this.fullWidth,
    required this.compactSize,
    required this.updateAvailable,
    this.onExpand,
    super.key,
  });

  final StatefulNavigationShell shell;
  final double progress;
  final double fullWidth;
  final double compactSize;
  final bool updateAvailable;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final branch = mobileParentBranch(shell.currentIndex);
    final active = kNavDestinations.firstWhere(
      (spec) => spec.branch == branch,
      orElse: () => kNavDestinations.first,
    );
    final badgedBranch = updateAvailable ? kSettingsBranch : null;
    return Stack(
      children: <Widget>[
        if (progress < 1) _expandedTabs(badgedBranch),
        if (progress > 0) _compactTab(context, active, badgedBranch),
      ],
    );
  }

  // 过渡中保留展开宽度，标签淡出，不被不断缩短的玻璃挤压。
  Widget _expandedTabs(int? badgedBranch) => Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    width: fullWidth,
    child: IgnorePointer(
      ignoring: progress > 0.5,
      child: ExcludeSemantics(
        excluding: progress > 0.5,
        child: Opacity(
          opacity: (1 - progress / 0.5).clamp(0.0, 1.0),
          child: BottomNavRow(
            shell: shell,
            badgedBranch: badgedBranch,
            hideSelectedIcon: progress > 0,
          ),
        ),
      ),
    ),
  );

  Widget _compactTab(
    BuildContext context,
    NavDestinationSpec active,
    int? badgedBranch,
  ) {
    final index = kNavDestinations.indexOf(active);
    final initialCenter = fullWidth * (index + 0.5) / kNavDestinations.length;
    final scaler = MediaQuery.textScalerOf(context);
    // 与展开项的 11 号/1.25 行高标签和 3px 间距对齐，移动图标从原位置接续。
    final initialY =
        (mobileDockHeight(scaler) - scaler.scale(11) * 1.25 - 3) / 2;
    return Positioned(
      left: lerpDouble(initialCenter - compactSize / 2, 0, progress),
      top: lerpDouble(initialY - compactSize / 2, 0, progress),
      height: compactSize,
      width: compactSize,
      child: IgnorePointer(
        ignoring: progress <= 0.5,
        child: ExcludeSemantics(
          excluding: progress <= 0.5,
          child: BottomNavItem(
            spec: active,
            active: true,
            compact: true,
            badged: badgedBranch == active.branch,
            onTap: () => onExpand?.call(),
          ),
        ),
      ),
    );
  }
}
