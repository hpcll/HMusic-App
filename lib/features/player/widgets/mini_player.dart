import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../view_models/player_view_model.dart';
import 'mini_player_card.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({this.capsule = false, this.inline = false, super.key});

  // 桌面壳注入内容区底部的让位高度：外边距 12 + 行内容 ~58 + 进度线 2 的
  // 包络，配合页面自身的 32 底距，列表末行不会停在玻璃下面。
  static const double desktopInset = kMiniPlayerDesktopInset;

  // 悬浮胶囊形态（窄屏 Flutter 回退壳）：高 50 胶囊悬在 dock（66）上方，
  // 矮一档分清主次；对齐 iOS 26+ 原生 GlassMiniPlayer。false = 桌面/宽屏玻璃卡形态。
  final bool capsule;

  // 收缩内联排布（仅胶囊形态）：chrome 收缩时 mini 与 dock 图标圆钮同排，
  // 内容不裁剪，只把与 dock 的 gap 从底部换到右侧。
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(hmusicAudioHandlerProvider);
    return handler.when(
      data: (audioHandler) => _MiniPlayerBody(
        audioHandler: audioHandler,
        capsule: capsule,
        inline: inline,
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
    required this.inline,
  });

  final HMusicAudioHandler audioHandler;
  final bool capsule;
  final bool inline;

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
                      inline: inline,
                    );
                  },
                ),
        );
      },
    );
  }
}
