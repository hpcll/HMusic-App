import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../../features/player/widgets/mini_player.dart';
import '../../shared/layout/shell_metrics.dart';
import 'bottom_nav.dart';
import 'top_bar.dart';

// 窄屏 Flutter 回退壳（Android/iOS<26）：用毛玻璃复刻 iOS 26+ 原生壳形态——
// mini 胶囊 + dock 胶囊压进安全区居底悬浮，内容 scroll-under。向下滚收缩：
// mini 与「当前 tab 图标圆钮」并成一排内联（对齐系统 dock 的收纳形态）；
// 只有滚回顶部、点圆钮或切 tab 才展开，中途向上滚保持收缩。
// chrome 仍走 Scaffold.bottomNavigationBar 槽位（骨架恒定可见，docs/03），
// extendBody 自动把 chrome 包络高度注入内容 MediaQuery 让位；胶囊四周的
// 透明留白不吃点击，命中穿到下层内容。
class FlutterGlassShell extends StatefulWidget {
  const FlutterGlassShell({
    required this.shell,
    required this.showMini,
    super.key,
  });

  final StatefulNavigationShell shell;
  final bool showMini;

  @override
  State<FlutterGlassShell> createState() => _FlutterGlassShellState();
}

class _FlutterGlassShellState extends State<FlutterGlassShell> {
  // mini 用 GlobalKey 在竖排/内联两种布局间搬家：element 连同 Stream 订阅
  // 一起复用，切换瞬间不会闪一帧空 mini。
  final GlobalKey _miniKey = GlobalKey();
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
    );
    final dock = AppBottomNav(
      shell: widget.shell,
      minimized: _minimized,
      onExpand: () => _setMinimized(false),
    );
    final mini = MiniPlayer(key: _miniKey, capsule: true, inline: _minimized);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(),
      body: ScrollMinimizeListener(
        onMinimized: _setMinimized,
        child: widget.shell,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          kChromeHorizontalPadding,
          kChromeContentClearance,
          kChromeHorizontalPadding,
          bottomOffset,
        ),
        // 展开 = mini 叠在 dock 上方（竖排）；收缩 = mini 内联 + 图标圆钮一排。
        // 结构切换的包络高度差由 AnimatedSize 以底边为锚过渡（docs/03 动效表）。
        child: AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : kChromeMorphDuration,
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: widget.showMini && _minimized
              ? Row(
                  children: <Widget>[
                    Expanded(child: mini),
                    dock,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[if (widget.showMini) mini, dock],
                ),
        ),
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
