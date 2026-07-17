import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../../features/player/widgets/mini_player.dart';
import '../../shared/layout/shell_metrics.dart';
import 'bottom_nav.dart';
import 'top_bar.dart';

// 窄屏 Flutter 回退壳（Android/iOS<26）：用毛玻璃复刻 iOS 26+ 原生壳形态——
// mini 胶囊 + dock 胶囊压进安全区居底悬浮，内容 scroll-under；向下滚 dock
// 收成单枚 pill、mini 收窄，向上滚展开（对齐 GlassShellOverlay）。
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.showMini)
              MiniPlayer(capsule: true, minimized: _minimized),
            AppBottomNav(
              shell: widget.shell,
              minimized: _minimized,
              onExpand: () => _setMinimized(false),
            ),
          ],
        ),
      ),
    );
  }
}

// 滚动方向 → chrome 收缩信号：向下滚收缩、向上滚展开，原生壳与回退壳共用。
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
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        switch (notification.direction) {
          case ScrollDirection.reverse:
            onMinimized(true);
          case ScrollDirection.forward:
            onMinimized(false);
          case ScrollDirection.idle:
            break;
        }
        return false;
      },
      child: child,
    );
  }
}
