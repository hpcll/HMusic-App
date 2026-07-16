import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/widgets/mini_player.dart';
import '../app_providers.dart';
import '../theme/hmusic_palette.dart';
import 'bottom_nav.dart';
import 'sidebar.dart';
import 'top_bar.dart';

// 自适应导航外壳：承载 7 个 StatefulShellRoute 分支，统一提供 chrome + mini player。
// 断点 860px（与 web 一致）：
//   窄屏 → 玻璃顶栏 + 内容 + 底部（mini 叠在 5-tab 玻璃底栏之上，内容从下滚过）。
//   宽屏 → 左侧栏 232 + 内容（mini 悬浮内容底部，让位走 MediaQuery 注入）。
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
    final miniActive = ref.watch(miniPlayerActiveProvider).value ?? false;

    if (isDesktop) {
      final media = MediaQuery.of(context);
      final showMini = !onPlayerTab;
      final bottomInset = showMini && miniActive
          ? MiniPlayer.desktopInset
          : 0.0;
      // macOS 窗体是窗后毛玻璃（MainFlutterWindow 垫 NSVisualEffectView），
      // 外壳不铺底色让半透明侧栏透出壁纸；内容区自己铺回不透明暖纸。
      final macGlassWindow = Theme.of(context).platform == TargetPlatform.macOS;
      return Scaffold(
        backgroundColor: macGlassWindow ? Colors.transparent : null,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSidebar(shell: navigationShell),
            Expanded(
              child: ColoredBox(
                color: context.palette.background,
                child: Stack(
                  children: <Widget>[
                    // 让位走 MediaQuery padding 注入而非留白，内容可滚到窗口
                    // 上沿/mini 之下（scroll-under）：顶部 28 = 隐藏系统标题栏
                    // 的让位基线（红绿灯悬浮区），底部 = 悬浮 mini 的包络高度。
                    Positioned.fill(
                      child: MediaQuery(
                        data: media.copyWith(
                          padding: media.padding.copyWith(
                            top: media.padding.top + 28,
                            bottom: media.padding.bottom + bottomInset,
                          ),
                        ),
                        child: navigationShell,
                      ),
                    ),
                    if (showMini)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: MiniPlayer(),
                      ),
                  ],
                ),
              ),
            ),
          ],
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
              extendBodyBehindAppBar: true,
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
        // extendBody / extendBodyBehindAppBar：内容延伸到玻璃顶栏与底部 chrome
        // 之下，Scaffold 自动把两者高度注入 body 的 MediaQuery padding，页面
        // 既有的 paddingOf.top/bottom 让位直接生效。底栏仍在 Scaffold 结构内
        // 恒定可见，不违反 docs/03「勿用悬浮 fixed 底栏」铁律。
        return Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
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
