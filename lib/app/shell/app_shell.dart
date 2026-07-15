import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/widgets/mini_player.dart';
import '../app_providers.dart';
import 'bottom_nav.dart';
import 'sidebar.dart';
import 'top_bar.dart';

// 自适应导航外壳：承载 7 个 StatefulShellRoute 分支，统一提供 chrome + mini player。
// 断点 860px（与 web 一致）：
//   窄屏 → 顶栏 + 内容 + 底部（mini 叠在 5-tab 底栏之上）。
//   宽屏 → 左侧栏 232 + 内容（mini 贴内容底部；侧栏 side-now 精修留后）。
// iOS 26+ 原生玻璃壳 ready 后接管窄屏 dock + mini：Flutter 隐藏自绘 chrome，
// 内容底部让出原生回报的 inset；原生不可用/低版本走既有 Flutter 壳，行为不变。
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final shellController = ref.watch(platformShellControllerProvider);
    return ListenableBuilder(
      listenable: shellController,
      builder: (context, _) {
        if (shellController.nativeChromeActive) {
          // 原生 dock/mini 悬浮在 Flutter 层之上；内容经 MediaQuery padding 让位——
          // 各页 ListView 的底部 padding 需累加 MediaQuery.paddingOf(context).bottom，
          // 玻璃下仍有内容滚动（scroll-under），列表末尾不被遮挡。
          // 滚动方向经 controller 上报原生：向下滚 dock 收缩，向上滚展开。
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: shellController.nativeBottomInset,
              ),
            ),
            child: Scaffold(
              appBar: const AppTopBar(),
              body: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.vertical) return false;
                  switch (notification.direction) {
                    case ScrollDirection.reverse:
                      shellController.reportScroll(minimized: true);
                    case ScrollDirection.forward:
                      shellController.reportScroll(minimized: false);
                    case ScrollDirection.idle:
                      break;
                  }
                  return false;
                },
                child: navigationShell,
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
      },
    );
  }
}
