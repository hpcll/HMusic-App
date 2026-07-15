import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'theme/hmusic_theme.dart';

class HMusicApp extends ConsumerWidget {
  const HMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 读取平台壳控制器以建立 intent 订阅；返回值不用，仅保持 provider 存活。
    ref.watch(platformShellControllerProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'HMusic',
      debugShowCheckedModeBanner: false,
      theme: HMusicTheme.light(),
      darkTheme: HMusicTheme.dark(),
      themeMode: ThemeMode.system,
      scrollBehavior: const _NoScrollbarBehavior(),
      routerConfig: router,
    );
  }
}

// 全局隐藏滚动条：桌面端默认 ScrollBehavior 会给每个可滚动区域自动包一层
// Scrollbar，这里返回 child 本身把它关掉；滚轮/触控板/拖拽滚动不受影响。
class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
