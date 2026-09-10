import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../view_models/player_view_model.dart';
import 'desktop_playback_content.dart';
import 'desktop_playback_metrics.dart';

export 'desktop_playback_metrics.dart' show desktopPlaybackBarHeight;

class DesktopPlaybackBar extends ConsumerWidget {
  const DesktopPlaybackBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverPlaybackStateProvider).value;
    if (state?.track == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DesktopPlaybackMetrics(
          contentWidth: constraints.maxWidth,
          textScaler: MediaQuery.textScalerOf(context),
        );
        return SizedBox(
          height: metrics.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: AdaptiveGlassSurface(
              quality: resolveGlassQuality(context),
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: DesktopPlaybackContent(state: state!, metrics: metrics),
            ),
          ),
        );
      },
    );
  }
}
