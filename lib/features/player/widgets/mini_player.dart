import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../view_models/player_view_model.dart';
import 'mini_player_card.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({this.capsule = false, this.minimized = false, super.key});

  // 桌面壳注入内容区底部的让位高度：外边距 12 + 行内容 ~58 + 进度线 2 的
  // 包络，配合页面自身的 32 底距，列表末行不会停在玻璃下面。
  static const double desktopInset = kMiniPlayerDesktopInset;

  // 悬浮胶囊形态（窄屏 Flutter 回退壳）：高 50 胶囊悬在 dock（66）上方，
  // 矮一档分清主次；对齐 iOS 26+ 原生 GlassMiniPlayer。false = 桌面/宽屏玻璃卡形态。
  final bool capsule;

  // 滚动收缩态（仅胶囊形态）：只留封面 + 播放/暂停，胶囊收窄居中。
  final bool minimized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(hmusicAudioHandlerProvider);
    return handler.when(
      data: (audioHandler) => _MiniPlayerBody(
        audioHandler: audioHandler,
        capsule: capsule,
        minimized: minimized,
      ),
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class _MiniPlayerBody extends ConsumerWidget {
  const _MiniPlayerBody({
    required this.audioHandler,
    required this.capsule,
    required this.minimized,
  });

  final HMusicAudioHandler audioHandler;
  final bool capsule;
  final bool minimized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, itemSnapshot) {
        final item = itemSnapshot.data;
        // docs/03 mini 显隐动效：出现/消失 220ms easeOut 高度过渡，不硬切。
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: item == null
              ? const SizedBox(width: double.infinity)
              : StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, stateSnapshot) {
                    return MiniPlayerCard(
                      item: item,
                      playbackState: stateSnapshot.data,
                      controller: ref.read(playerViewModelProvider),
                      capsule: capsule,
                      minimized: minimized,
                    );
                  },
                ),
        );
      },
    );
  }
}
