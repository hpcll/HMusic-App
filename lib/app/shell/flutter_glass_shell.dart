import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../core/upgrade/app_update_badge.dart';
import '../../features/player/widgets/mini_player.dart';
import '../../features/search/views/search_page.dart';
import '../../shared/layout/shell_metrics.dart';
import 'bottom_nav.dart';
import 'scroll_minimize_listener.dart';
import 'top_edge_scrim.dart';

export 'scroll_minimize_listener.dart';

// 展开沿用 mini 在上、dock 在下的外观；滚动时连续收成左导航/中 mini/右搜索。
// 一条进度同时驱动位置、尺寸与内容淡出，透明留白允许内容穿透点击。
class FlutterGlassShell extends ConsumerStatefulWidget {
  const FlutterGlassShell({
    required this.shell,
    required this.showMini,
    super.key,
  });

  final StatefulNavigationShell shell;
  final bool showMini;

  @override
  ConsumerState<FlutterGlassShell> createState() => _FlutterGlassShellState();
}

class _FlutterGlassShellState extends ConsumerState<FlutterGlassShell> {
  bool _minimized = false;
  int _lastBranch = -1;

  void _setMinimized(bool value) {
    if (value != _minimized) setState(() => _minimized = value);
  }

  @override
  Widget build(BuildContext context) {
    // 换 tab 后 dock 回到展开态，新页面的滚动从头计（对齐原生壳行为）。
    if (widget.shell.currentIndex != _lastBranch) {
      _lastBranch = widget.shell.currentIndex;
      _minimized = false;
    }
    final allowMinimize =
        widget.showMini &&
        canMinimizeBottomChrome(
          viewportWidth: MediaQuery.sizeOf(context).width,
          textScaler: MediaQuery.textScalerOf(context),
        );
    if (!allowMinimize) _minimized = false;
    final bottomOffset = chromeBottomOffset(
      MediaQuery.paddingOf(context).bottom,
      platform: Theme.of(context).platform,
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    // 红点随检查结果变化要能重建（provider 只在这一处 watch，dock 自身不碰）。
    ref.watch(appUpdateBadgeProvider);
    return Scaffold(
      extendBody: true,
      // 无常驻顶栏（对齐 Apple Music）：状态栏区只留滚动消融 scrim，
      // 品牌见登录页，退出登录在设置页。
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ScrollMinimizeListener(
              onMinimized: (value) => _setMinimized(value && allowMinimize),
              child: widget.shell,
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: TopEdgeScrim()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          kChromeHorizontalPadding,
          kChromeContentClearance,
          kChromeHorizontalPadding,
          bottomOffset,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _minimized ? 1 : 0),
              duration: disableAnimations
                  ? Duration.zero
                  : kChromeMorphDuration,
              curve: kChromeMorphCurve,
              builder: (context, t, _) => _chrome(context, width, t),
            );
          },
        ),
      ),
    );
  }

  Widget _chrome(BuildContext context, double width, double t) {
    final scaler = MediaQuery.textScalerOf(context);
    final miniHeight = mobileMiniPlayerHeight(scaler);
    final dockHeight = mobileDockHeight(scaler);
    final expandedHeight =
        dockHeight + (widget.showMini ? miniHeight + kChromeGap : 0);
    final height = lerpDouble(expandedHeight, miniHeight, t)!;
    final sideSpace = (miniHeight + kChromeGap) * t;
    final miniWidth = width - 2 * sideSpace;
    final miniBottom = (dockHeight + kChromeGap) * (1 - t);
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Align(
            alignment: Alignment.bottomLeft,
            child: AppBottomNav(
              shell: widget.shell,
              progress: t,
              // 有 App 新版 = 设置 tab 点红点（唯一的更新提示位）。
              updateAvailable: ref
                  .read(appUpdateBadgeProvider.notifier)
                  .hasUpdate,
              onExpand: () => _setMinimized(false),
            ),
          ),
          if (t > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: _search(context, miniHeight, t),
            ),
          if (widget.showMini)
            Positioned(
              left: sideSpace,
              width: miniWidth,
              bottom: miniBottom,
              child: MiniPlayer(capsule: true, compactProgress: t),
            ),
        ],
      ),
    );
  }

  Widget _search(BuildContext context, double size, double progress) =>
      IgnorePointer(
        ignoring: progress < 0.5,
        child: ExcludeSemantics(
          excluding: progress < 0.5,
          child: Opacity(
            opacity: progress,
            child: AdaptiveGlassSurface(
              quality: resolveGlassQuality(context),
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(size / 2),
              child: SizedBox.square(
                dimension: size,
                child: IconButton(
                  tooltip: '搜索',
                  icon: const Icon(Icons.search_rounded, size: kDockIconSize),
                  onPressed: () => unawaited(context.push(SearchPage.path)),
                ),
              ),
            ),
          ),
        ),
      );
}
