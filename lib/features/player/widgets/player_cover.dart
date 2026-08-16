import 'package:flutter/material.dart';

import '../../../core/models/hmusic_track.dart';

class PlayerCover extends StatelessWidget {
  const PlayerCover({required this.track, super.key});

  final HMusicTrack? track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = track?.coverUrl;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: url == null
              ? _fallback(scheme)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // 舞台封面布局上限 420 逻辑像素（player_page 约束），窄屏
                  // 屏宽也低于此值；按 420 解码防原图全尺寸解码。
                  cacheWidth: (420 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  // 网络慢时首帧淡入，替代空白→硬切；同步缓存命中不动画。
                  frameBuilder: (context, child, frame, syncLoaded) {
                    if (syncLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: child,
                    );
                  },
                  errorBuilder: (_, __, ___) => _fallback(scheme),
                ),
        ),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: 72, color: scheme.onSurfaceVariant),
    );
  }
}
