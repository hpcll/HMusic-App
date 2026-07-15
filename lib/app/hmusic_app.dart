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
      routerConfig: router,
    );
  }
}
