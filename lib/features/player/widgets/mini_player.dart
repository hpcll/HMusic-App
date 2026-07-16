import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../view_models/player_view_model.dart';
import '../views/player_page.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  // 桌面壳注入内容区底部的让位高度：外边距 12 + 行内容 ~58 + 进度线 2 的
  // 包络，配合页面自身的 32 底距，列表末行不会停在玻璃下面。
  static const double desktopInset = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(hmusicAudioHandlerProvider);
    return handler.when(
      data: (audioHandler) => _MiniPlayerBody(audioHandler: audioHandler),
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class _MiniPlayerBody extends ConsumerWidget {
  const _MiniPlayerBody({required this.audioHandler});

  final HMusicAudioHandler audioHandler;

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
                    return _MiniPlayerCard(
                      item: item,
                      playbackState: stateSnapshot.data,
                      controller: ref.read(playerViewModelProvider),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _MiniPlayerCard extends StatelessWidget {
  const _MiniPlayerCard({
    required this.item,
    required this.playbackState,
    required this.controller,
  });

  final MediaItem item;
  final PlaybackState? playbackState;
  final PlayerViewModel controller;

  @override
  Widget build(BuildContext context) {
    final isPlaying = playbackState?.playing ?? false;

    // 外壳负责安全区与堆叠位置；mini 只保留自身左右留白与小幅上下间距。
    // 对齐 docs/03「mini player：封面、题/歌手、播放与下一曲」的玻璃控制条形态：
    // 内容从玻璃下滚过，off 档（高对比/减动效）自动退回不透明面板。
    // 不显示进度：进度与 seek 都归完整播放页，mini 只承载识别与启停。
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: AdaptiveGlassSurface(
        quality: resolveGlassQuality(context),
        padding: EdgeInsets.zero,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openPlayer(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: <Widget>[
                  _Cover(url: item.artUri?.toString()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TrackText(title: item.title, artist: item.artist),
                  ),
                  IconButton(
                    tooltip: isPlaying ? '暂停' : '播放',
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    iconSize: 30,
                    onPressed: isPlaying ? controller.pause : controller.play,
                  ),
                  IconButton(
                    tooltip: '下一首',
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 26,
                    onPressed: controller.skipToNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 桌面（≥860）→ 切到「正在播放」tab（go 切分支，外壳常驻）；
  // 窄屏 → push 全屏播放页（移动专属交互，下滑/返回可退出）。
  void _openPlayer(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    if (wide) {
      context.go(PlayerPage.tabPath);
    } else {
      unawaited(context.push(PlayerPage.path));
    }
  }
}

// mini 小方封面，复用全站封面原子。
class _Cover extends StatelessWidget {
  const _Cover({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return HMusicCover(url: url, size: 42, radius: 8, iconSize: 18);
  }
}

class _TrackText extends StatelessWidget {
  const _TrackText({required this.title, required this.artist});

  final String title;
  final String? artist;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
        if (artist != null && artist!.isNotEmpty)
          Text(
            artist!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
      ],
    );
  }
}
