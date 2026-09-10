import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/playback/playback_mode.dart';
import '../../core/playback/playback_mode_controller.dart';
import '../../features/player/widgets/desktop_playback_bar.dart';
import '../../shared/layout/shell_metrics.dart';
import '../theme/hmusic_palette.dart';
import 'mi_session_banner.dart';
import 'sidebar.dart';

class SideNavigationShell extends ConsumerWidget {
  const SideNavigationShell({
    required this.shell,
    required this.mode,
    required this.miniActive,
    super.key,
  });

  final StatefulNavigationShell shell;
  final ShellNavigationMode mode;
  final bool miniActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = Theme.of(context).platform;
    return Scaffold(
      backgroundColor: platform == TargetPlatform.macOS
          ? Colors.transparent
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSidebar(shell: shell, rail: mode == ShellNavigationMode.rail),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final media = MediaQuery.of(context);
                final titleInset = shellWindowTopInset(platform);
                final showPlayer = shell.currentIndex != 0;
                final playerHeight = showPlayer && miniActive
                    ? desktopPlaybackBarHeight(
                        contentWidth: constraints.maxWidth,
                        textScaler: media.textScaler,
                      )
                    : 0.0;
                return ColoredBox(
                  color: context.palette.background,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: MediaQuery(
                          data: media.copyWith(
                            padding: media.padding.copyWith(
                              top: media.padding.top + titleInset,
                              bottom: media.padding.bottom + playerHeight,
                            ),
                          ),
                          // 隔离嵌套 Navigator 的 BlockSemantics，避免它屏蔽同级侧栏。
                          child: Semantics(container: true, child: shell),
                        ),
                      ),
                      if (showPlayer)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: media.padding.bottom,
                          child: const DesktopPlaybackBar(),
                        ),
                      if (ref.watch(playbackModeProvider) ==
                          PlaybackMode.server)
                        Positioned(
                          top: media.padding.top + titleInset + 8,
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
