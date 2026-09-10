import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/playback/playback_mode.dart';
import '../../core/playback/playback_mode_controller.dart';
import '../../core/upgrade/upgrade_gate.dart';
import '../../features/player/view_models/player_view_model.dart';
import '../../features/settings/view_models/mi_session_watch_view_model.dart';
import '../../shared/layout/shell_metrics.dart';
import '../app_providers.dart';
import 'flutter_glass_shell.dart';
import 'home_back_fallback.dart';
import 'mi_session_banner.dart';
import 'native_glass_body.dart';
import 'platform_shell_viewport.dart';
import 'side_navigation_shell.dart';

export 'home_back_fallback.dart';

// 外壳负责三档导航与平台 chrome；各页依据剩余内容宽度选择自己的布局。
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverMode = ref.watch(playbackModeProvider) == PlaybackMode.server;
    if (serverMode &&
        !ref.watch(upgradeGateProvider.select((s) => s.checked))) {
      unawaited(
        Future<void>.microtask(
          () => ref.read(upgradeGateProvider.notifier).check(),
        ),
      );
    }
    ref.listen(playbackNoticeProvider, (_, next) {
      if (serverMode && !next.isLoading && next.value != null) {
        unawaited(ref.read(miSessionWatchProvider.notifier).refreshQuick());
      }
    });
    final mode = shellNavigationModeForWidth(MediaQuery.sizeOf(context).width);
    final miniActive = ref.watch(miniPlayerActiveProvider);
    final overlay =
        (Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent);
    return PlatformShellViewport(
      child: HomeBackFallback(
        shell: navigationShell,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: mode == ShellNavigationMode.bottom
              ? _bottomShell(context, ref, miniActive)
              : SideNavigationShell(
                  shell: navigationShell,
                  mode: mode,
                  miniActive: miniActive,
                ),
        ),
      ),
    );
  }

  Widget _bottomShell(BuildContext context, WidgetRef ref, bool miniActive) {
    final controller = ref.watch(platformShellControllerProvider);
    return Stack(
      children: <Widget>[
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.nativeChromeActive
              ? NativeGlassBody(shell: navigationShell, controller: controller)
              : FlutterGlassShell(
                  shell: navigationShell,
                  showMini: navigationShell.currentIndex != 0,
                ),
        ),
        if (ref.watch(playbackModeProvider) == PlaybackMode.server)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: const MiSessionBanner(),
              ),
            ),
          ),
      ],
    );
  }
}
