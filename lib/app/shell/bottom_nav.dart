import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../shared/layout/shell_metrics.dart';
import 'bottom_nav_transition.dart';

export 'bottom_nav_item.dart' show kDockIconSize;
export 'navigation_destinations.dart';

// 外壳统一驱动收纳进度；展开布局不变，收起时导航落在左侧圆钮。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.shell,
    this.progress = 0,
    this.onExpand,
    this.updateAvailable = false,
    super.key,
  });

  final StatefulNavigationShell shell;
  final double progress;
  final VoidCallback? onExpand;
  final bool updateAvailable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildDock(context, progress, constraints.maxWidth),
    );
  }

  Widget _buildDock(BuildContext context, double t, double fullWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final height = lerpDouble(
      mobileDockHeight(scaler),
      mobileMiniPlayerHeight(scaler),
      t,
    )!;
    final compactSize = mobileMiniPlayerHeight(scaler);
    final width = lerpDouble(fullWidth, compactSize, t)!;
    final radius = BorderRadius.circular(height / 2);
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.zero,
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: BottomNavTransition(
            shell: shell,
            progress: t,
            fullWidth: fullWidth,
            compactSize: compactSize,
            updateAvailable: updateAvailable,
            onExpand: onExpand,
          ),
        ),
      ),
    );
  }
}
