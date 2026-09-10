import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/direct/direct_lifecycle.dart';
import '../core/direct/direct_session_providers.dart';
import '../core/session/session_providers.dart';
import '../core/upgrade/app_update_badge.dart';
import '../core/upgrade/app_version_guard.dart';
import '../features/settings/view_models/auto_archive_view_model.dart';
import 'app_providers.dart';
import 'shell/desktop_playback_shortcuts.dart';
import 'theme/hmusic_theme.dart';

class HMusicApp extends ConsumerWidget {
  const HMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 读取平台壳控制器以建立 intent 订阅；返回值不用，仅保持 provider 存活。
    ref.watch(platformShellControllerProvider);
    // 会话失效副作用（停本机音频）在 app 根激活。不能由 apiClient 拉起：
    // guard 会进 audioHandler 的依赖链，其监听器反读 audioHandler 即成环。
    ref.watch(sessionGuardProvider);
    ref.watch(directSessionGuardProvider);
    ref.watch(directLifecycleProvider);
    // 服务端 403 拒绝老版本 → 立即关强升门（同上，不能由 apiClient 拉起）。
    ref.watch(appVersionGuardProvider);
    // 「播放过的在线歌自动入库」的执行体：挂在根上，任何页面点播都算听过。
    ref.watch(autoArchiveWatcherProvider);
    // 进 App 静默检一次 App 新版（6h 节流，落盘）：结果只表现为设置入口的
    // 红点，不弹窗不横幅。
    ref.watch(appUpdateBadgeProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'HMusic',
      debugShowCheckedModeBanner: false,
      theme: HMusicTheme.light(),
      darkTheme: HMusicTheme.dark(),
      themeMode: ThemeMode.system,
      // 桌面键盘快捷键挂在 Navigator 之上：push 出去的播放页/弹层同样生效。
      builder: (context, child) =>
          DesktopPlaybackShortcuts(child: child ?? const SizedBox.shrink()),
      routerConfig: router,
    );
  }
}
