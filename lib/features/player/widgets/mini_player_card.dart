import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../view_models/player_view_model.dart';
import '../views/player_page.dart';

// mini player 展示卡，对齐 docs/03「mini player：封面、题/歌手、播放与下一曲」
// 的玻璃控制条形态：内容从玻璃下滚过，off 档（高对比/减动效）自动退回不透明
// 面板。不显示进度：进度与 seek 都归完整播放页，mini 只承载识别与启停。
// 两种形态：
//   桌面/宽屏（capsule=false）：圆角 18 玻璃卡，自带 12/6 外边距。
//   悬浮胶囊（capsule=true）：高 50 胶囊悬在 dock（66）上方（Flutter 回退壳），
//   比 dock 矮一档、封面/字号/图标同步收小——dock 是导航主锚点，mini 只是
//   次级播放状态条；对齐 iOS 26+ 原生 GlassMiniPlayer。左右留白由外壳统一，
//   自身只留与 dock 的 gap：竖排时在底部，收缩内联（inline）时换到右侧
//   （与图标圆钮之间），内容不裁剪，只随剩余宽度截断题/歌手。
class MiniPlayerCard extends StatelessWidget {
  const MiniPlayerCard({
    required this.item,
    required this.playbackState,
    required this.controller,
    this.capsule = false,
    this.inline = false,
    super.key,
  });

  final MediaItem item;
  final PlaybackState? playbackState;
  final PlayerViewModel controller;
  final bool capsule;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final isPlaying = playbackState?.playing ?? false;
    final radius = BorderRadius.all(
      Radius.circular(capsule ? kChromeMiniHeight / 2 : 18),
    );
    final row = Row(
      children: <Widget>[
        _Cover(url: item.artUri?.toString(), capsule: capsule),
        const SizedBox(width: 12),
        Expanded(
          child: _TrackText(
            title: item.title,
            artist: item.artist,
            capsule: capsule,
          ),
        ),
        IconButton(
          tooltip: isPlaying ? '暂停' : '播放',
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
          iconSize: capsule ? 26 : 30,
          onPressed: isPlaying ? controller.pause : controller.play,
        ),
        IconButton(
          tooltip: '下一首',
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: capsule ? 22 : 26,
          onPressed: controller.skipToNext,
        ),
      ],
    );
    final EdgeInsets margin;
    if (!capsule) {
      margin = const EdgeInsets.fromLTRB(12, 6, 12, 6);
    } else if (inline) {
      margin = const EdgeInsets.only(right: kChromeGap);
    } else {
      margin = const EdgeInsets.only(bottom: kChromeGap);
    }
    return Padding(
      padding: margin,
      child: AdaptiveGlassSurface(
        quality: resolveGlassQuality(context),
        padding: EdgeInsets.zero,
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openPlayer(context),
            child: capsule
                ? SizedBox(
                    height: kChromeMiniHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: row,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    child: row,
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

// mini 小方封面，复用全站封面原子。胶囊形态收小到 32：缩略图只做识别，
// 不抢 dock 的视觉主导（原生 GlassMiniPlayer artwork 同尺寸）。
class _Cover extends StatelessWidget {
  const _Cover({required this.capsule, this.url});

  final String? url;
  final bool capsule;

  @override
  Widget build(BuildContext context) {
    return capsule
        ? HMusicCover(url: url, size: 32, radius: 7, iconSize: 13)
        : HMusicCover(url: url, size: 42, radius: 8, iconSize: 18);
  }
}

class _TrackText extends StatelessWidget {
  const _TrackText({
    required this.title,
    required this.artist,
    required this.capsule,
  });

  final String title;
  final String? artist;
  final bool capsule;

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
          // 胶囊题名降到 titleSmall（14），对齐原生 GlassMiniPlayer 的 14 号纪律。
          style: capsule ? textTheme.titleSmall : textTheme.titleMedium,
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
