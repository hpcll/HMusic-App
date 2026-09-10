import 'package:flutter/material.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../shared/layout/shell_metrics.dart';

// 展开保留原来的曲名/歌手两行，收起时歌手逐渐让位，只留曲名。
class MiniPlayerTrackInfo extends StatelessWidget {
  const MiniPlayerTrackInfo({
    required this.state,
    required this.onOpenPlayer,
    this.compactProgress = 0,
    super.key,
  });

  final HMusicPlaybackState? state;
  final VoidCallback? onOpenPlayer;
  final double compactProgress;

  @override
  Widget build(BuildContext context) {
    final track = state?.track;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final detailStyle = TextStyle(
      fontSize: kChromeMiniDetailFontSize,
      height: kChromeMiniLineHeight,
      color: muted,
    );
    return Semantics(
      button: onOpenPlayer != null,
      label: track == null ? '未在播放' : '${track.title}，${track.artist}，打开播放器',
      onTap: onOpenPlayer,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenPlayer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              track?.title ?? '未在播放',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: kChromeMiniTitleFontSize,
                height: kChromeMiniLineHeight,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (track != null && track.artist.isNotEmpty && compactProgress < 1)
              ClipRect(
                child: Align(
                  alignment: Alignment.topLeft,
                  heightFactor: 1 - compactProgress,
                  child: Opacity(
                    opacity: 1 - compactProgress,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: detailStyle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
