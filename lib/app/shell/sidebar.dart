import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/playback/playback_mode.dart';
import '../../core/playback/playback_mode_controller.dart';
import '../../core/playback/playback_mode_switch.dart';
import '../../core/providers/infrastructure_providers.dart';
import '../../core/session/session_providers.dart';
import '../../shared/layout/shell_metrics.dart';
import '../theme/hmusic_palette.dart';
import 'sidebar_content.dart';

// rail 与完整侧栏使用同一组目的地，列表可滚动，矮窗和大字都不会挤掉入口。
class AppSidebar extends ConsumerWidget {
  const AppSidebar({required this.shell, this.rail = false, super.key});

  final StatefulNavigationShell shell;
  final bool rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final platform = Theme.of(context).platform;
    final macGlassWindow = platform == TargetPlatform.macOS;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: rail ? kNavigationRailWidth : kSidebarWidth,
      decoration: BoxDecoration(
        color: macGlassWindow
            ? palette.background.withValues(alpha: dark ? 0.55 : 0.60)
            : palette.background,
        border: Border(right: BorderSide(color: palette.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        rail ? 12 : 22,
        MediaQuery.paddingOf(context).top + shellWindowTopInset(platform) + 24,
        rail ? 12 : 22,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SidebarBrandHeader(rail: rail),
          Expanded(
            child: SidebarNavigation(shell: shell, rail: rail),
          ),
          const SizedBox(height: 10),
          if (ref.watch(playbackModeProvider) != PlaybackMode.player)
            _logoutControl(ref),
        ],
      ),
    );
  }

  Widget _logoutControl(WidgetRef ref) {
    if (rail) {
      return IconButton(
        tooltip: '退出登录',
        onPressed: () => _logout(ref),
        icon: const Icon(Icons.logout_rounded, size: 20),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _logout(ref),
        icon: const Icon(Icons.logout_rounded, size: 16),
        label: const Text('退出登录'),
      ),
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    if (ref.read(playbackModeProvider) == PlaybackMode.direct) {
      await ref.read(playbackModeSwitchProvider.notifier).logoutDirect();
      return;
    }
    await ref.read(tokenStoreProvider).clear();
    ref.read(sessionControllerProvider).invalidate();
  }
}
