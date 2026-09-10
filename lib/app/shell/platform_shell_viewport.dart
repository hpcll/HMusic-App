import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/layout/shell_metrics.dart';
import '../app_providers.dart';

// 窗口/文字变化独立于路由变化，帧后下发避免通知正在构建的内容树。
class PlatformShellViewport extends ConsumerStatefulWidget {
  const PlatformShellViewport({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PlatformShellViewport> createState() =>
      _PlatformShellViewportState();
}

class _PlatformShellViewportState extends ConsumerState<PlatformShellViewport> {
  Object? _lastConfiguration;
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(platformShellControllerProvider);
    final media = MediaQuery.of(context);
    final scaler = media.textScaler;
    final useBottom = usesBottomNavigation(media.size.width);
    final height = mobileMiniPlayerHeight(scaler);
    final title = scaler.scale(kChromeMiniTitleFontSize);
    final detail = scaler.scale(kChromeMiniDetailFontSize);
    final minimize = canMinimizeBottomChrome(
      viewportWidth: media.size.width,
      textScaler: scaler,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final configuration = (
      controller,
      useBottom,
      height,
      title,
      detail,
      minimize,
      dark,
      media.disableAnimations,
      media.highContrast,
    );
    if (configuration != _lastConfiguration) {
      _lastConfiguration = configuration;
      final revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        controller.updateViewport(
          useBottomChrome: useBottom,
          miniPlayerHeight: height,
          miniTitleFontSize: title,
          miniDetailFontSize: detail,
          allowMinimize: minimize,
        );
        unawaited(
          controller.configure(
            darkMode: dark,
            reduceMotion: media.disableAnimations,
            reduceTransparency: media.highContrast,
          ),
        );
      });
    }
    return widget.child;
  }
}
