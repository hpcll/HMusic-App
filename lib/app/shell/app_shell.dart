import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/widgets/mini_player.dart';
import 'bottom_nav.dart';
import 'sidebar.dart';
import 'top_bar.dart';

// 自适应导航外壳：承载 5 个 StatefulShellRoute 分支，统一提供 chrome + mini player。
// 断点 860px（与 web 一致）：
//   窄屏 → 顶栏 + 内容 + 底部（mini 叠在 5-tab 底栏之上）。
//   宽屏 → 左侧栏 232 + 内容（mini 贴内容底部；侧栏 side-now 精修留后）。
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 860;
    // 正在播放分支（branch 0）本身就是完整播放视图，mini player 冗余，隐藏。
    final onPlayerTab = navigationShell.currentIndex == 0;

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppSidebar(shell: navigationShell),
              Expanded(
                child: Column(
                  children: <Widget>[
                    // 桌面隐藏了系统标题栏（fullSizeContentView），内容会顶死窗口上沿。
                    // 留出标题栏高度的顶部余量，让页面大标题从这条基线往下排，不贴边。
                    const SizedBox(height: 28),
                    Expanded(child: navigationShell),
                    if (!onPlayerTab) const MiniPlayer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const AppTopBar(),
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!onPlayerTab) const MiniPlayer(),
          AppBottomNav(shell: navigationShell),
        ],
      ),
    );
  }
}
