import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/upgrade/app_update_badge.dart';
import '../../features/player/widgets/mini_player.dart';
import '../../shared/layout/shell_metrics.dart';
import 'bottom_nav.dart';
import 'top_edge_scrim.dart';

// 窄屏 Flutter 回退壳（Android/iOS<26）：用毛玻璃复刻 iOS 26+ 原生壳形态——
// mini 胶囊 + dock 胶囊压进安全区居底悬浮，内容 scroll-under。向下滚收缩：
// dock 胶囊「向右缩短」成当前 tab 的图标圆钮，mini 同时从 dock 上方飞落到
// 圆钮左侧同排——宽/高/位置全程几何连续插值（对齐原生壳 matchedGeometryEffect
// 手感），不做结构硬切；只有滚回顶部、点圆钮或切 tab 才展开，中途向上滚
// 保持收缩。chrome 仍走 Scaffold.bottomNavigationBar 槽位（骨架恒定可见，
// docs/03），extendBody 自动把 chrome 包络高度注入内容 MediaQuery 让位；
// 胶囊四周的透明留白不吃点击，命中穿到下层内容。
class FlutterGlassShell extends ConsumerStatefulWidget {
  const FlutterGlassShell({
    required this.shell,
    required this.showMini,
    required this.miniActive,
    super.key,
  });

  final StatefulNavigationShell shell;
  final bool showMini;

  // 当前是否有曲目占据 mini（外层依播放状态提供）：只驱动展开态包络高度的
  // mini 在场度插值——无曲目时包络不为空 mini 留高；dock 槽位不受它影响，
  // 收缩圆钮恒钉最右。
  final bool miniActive;

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
    final bottomOffset = chromeBottomOffset(
      MediaQuery.paddingOf(context).bottom,
      platform: Theme.of(context).platform,
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final miniVisible = widget.showMini && widget.miniActive;
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
              onMinimized: _setMinimized,
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
        // 两条独立插值共同驱动单帧几何（docs/03 §4）：
        //   t = 收纳进度（dock 缩短 + mini 下落），320ms easeOutCubic；
        //   v = mini 在场度（曲目出现/消失），220ms easeOut（docs/05 节奏）。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _minimized ? 1 : 0),
              duration: disableAnimations
                  ? Duration.zero
                  : kChromeMorphDuration,
              curve: kChromeMorphCurve,
              builder: (context, t, _) => TweenAnimationBuilder<double>(
                tween: Tween<double>(end: miniVisible ? 1 : 0),
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, v, _) => _chrome(context, width, t, v),
              ),
            );
          },
        ),
      ),
    );
  }

  // 单帧 chrome 几何：包络高度、dock 槽位与 mini 飞行轨迹全部由 (t, v) 算出。
  // dock 的宽高收缩在 AppBottomNav 内按同目标/同时长/同曲线插值，逐帧对齐。
  Widget _chrome(BuildContext context, double width, double t, double v) {
    // 包络：展开 = dock 66 + mini 在场的 (50 + gap 8)；收缩 = 单排 50。
    final expandedHeight =
        kChromeDockHeight + (kChromeMiniHeight + kChromeGap) * v;
    final height = lerpDouble(expandedHeight, kChromeMiniHeight, t)!;
    // mini：左缘钉住，宽度渐让出圆钮 + gap，底缘从 dock 上方 (66+8) 落到贴底。
    final miniWidth = width - (kChromeCompactDockWidth + kChromeGap) * t;
    final miniBottom = (kChromeDockHeight + kChromeGap) * (1 - t);
    return SizedBox(
      height: height,
      child: Stack(
        // mini 出现瞬间可短暂越出包络顶 ≤gap，属两条插值的节奏差，不裁剪。
        clipBehavior: Clip.none,
        children: <Widget>[
          // dock 槽位恒钉右下：收缩圆钮固定收在最右侧（有无 mini 都一样，
          // 与原生壳一致——mini 只是从左侧让位进来，不改变圆钮落点）。
          Align(
            alignment: Alignment.bottomRight,
            child: AppBottomNav(
              shell: widget.shell,
              minimized: _minimized,
              // 有 App 新版 = 设置 tab 点红点（唯一的更新提示位）。
              updateAvailable: ref
                  .read(appUpdateBadgeProvider.notifier)
                  .hasUpdate,
              onExpand: () => _setMinimized(false),
            ),
          ),
          // mini 后画：飞行途中压在 dock 上层，落位后与圆钮同排互不遮挡。
          if (widget.showMini)
            Positioned(
              left: 0,
              width: miniWidth,
              bottom: miniBottom,
              child: const MiniPlayer(capsule: true),
            ),
        ],
      ),
    );
  }
}

// 滚动 → chrome 收缩信号，原生壳与回退壳共用：向下滚（内容上滑）即收缩；
// 展开只在滚回列表顶部时发生，中途向上滚保持收缩（对齐 iOS 26+ 系统 dock）。
class ScrollMinimizeListener extends StatelessWidget {
  const ScrollMinimizeListener({
    required this.onMinimized,
    required this.child,
    super.key,
  });

  final ValueChanged<bool> onMinimized;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.reverse) {
          onMinimized(true);
        } else if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          // 半像素容差吸收 ballistic 归位的浮点残差；不可滚动页面的橡皮筋
          // 回弹结束也落在这里，松手即恢复展开。
          if (notification.metrics.extentBefore < 0.5) onMinimized(false);
        }
        return false;
      },
      child: child,
    );
  }
}
