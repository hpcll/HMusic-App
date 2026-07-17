import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/view_models/player_view_model.dart';
import '../../features/player/widgets/mini_player.dart';
import '../../shared/widgets/hmusic_toast.dart';
import '../app_providers.dart';
import '../theme/hmusic_palette.dart';
import 'flutter_glass_shell.dart';
import 'sidebar.dart';
import 'top_bar.dart';

// 自适应导航外壳：承载 7 个 StatefulShellRoute 分支，统一提供 chrome + mini player。
// 断点 860px（与 web 一致）：
//   窄屏 → 玻璃顶栏 + 内容 + 底部悬浮玻璃 chrome（mini 胶囊 + dock 胶囊）。
//   宽屏 → 左侧栏 232 + 内容（mini 悬浮内容底部，让位走 MediaQuery 注入）。
// iOS 26+ 原生玻璃壳 ready 后接管窄屏 dock + mini：Flutter 隐藏自绘 chrome，
// 内容底部让出原生回报的 inset；原生不可用/低版本走 FlutterGlassShell 毛玻璃
// 回退壳，形态与原生壳一致（悬浮胶囊 + 滚动收缩），仅材质不同。
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 播放链路的全局失败通知：自动切歌等后台路径没有页面级 VM 兜着，只能在
    // 常驻壳层统一弹 toast（各页自己的 notice 监听照旧）。isLoading 挡掉
    // provider 重建时带旧值的过渡帧，避免旧通知重弹。
    ref.listen(playbackNoticeProvider, (_, next) {
      if (next.isLoading) return;
      final notice = next.value;
      if (notice != null) showHMusicToast(context, notice);
    });
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
              body: ScrollMinimizeListener(
                onMinimized: (minimized) =>
                    shellController.reportScroll(minimized: minimized),
                child: navigationShell,
              ),
            ),
          );
        }
        return FlutterGlassShell(
          shell: navigationShell,
          showMini: !onPlayerTab,
        );
      },
    );
  }
}
