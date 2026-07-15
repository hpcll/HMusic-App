import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../view_models/player_view_model.dart';
import '../views/player_page.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

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
        if (item == null) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, stateSnapshot) {
            return _MiniPlayerCard(
              item: item,
              playbackState: stateSnapshot.data,
              controller: ref.read(playerViewModelProvider),
            );
          },
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
    final theme = Theme.of(context);
    final duration = item.duration ?? Duration.zero;
    final position = _safePosition(playbackState?.updatePosition, duration);
    final isPlaying = playbackState?.playing ?? false;
    final progress = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // 外壳负责安全区与堆叠位置；mini 只保留自身左右留白与小幅上下间距。
    // 对齐 docs/03「mini player：封面、题/歌手、播放与下一曲」的玻璃控制条形态。
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openPlayer(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
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
              // 底部细进度条：只读指示（拖拽 seek 留在全屏播放页），
              // 与 web mini 控制条同构——mini 不承载精确 seek 交互。
              if (duration > Duration.zero)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
            ],
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

  Duration _safePosition(Duration? value, Duration duration) {
    final position = value ?? Duration.zero;
    if (position < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
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
