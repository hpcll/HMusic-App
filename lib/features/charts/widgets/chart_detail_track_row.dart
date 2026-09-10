import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../shared/widgets/hmusic_confirm_button.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';
import '../models/chart.dart';
import '../view_models/charts_view_model.dart';

// 详情行保留排名、当前播放标识和入库/队列反馈；页面只编排懒加载列表。
class ChartDetailTrackRow extends StatelessWidget {
  const ChartDetailTrackRow({
    required this.entry,
    required this.playingTrack,
    required this.notifier,
    required this.archived,
    required this.archiving,
    required this.enabled,
    required this.showDivider,
    this.downloadsEnabled = true,
    super.key,
  });

  final ChartEntry entry;
  final HMusicTrack? playingTrack;
  final ChartsViewModel notifier;
  final bool archived;
  final bool archiving;
  final bool enabled;
  final bool showDivider;
  final bool downloadsEnabled;

  bool get _isPlaying {
    final playing = playingTrack;
    if (playing == null) return false;
    if (entry.track != null) return entry.track!.id == playing.id;
    // Apple 榜匹配后 id 可能不同，沿用标题/歌手回退规则。
    return entry.title == playing.title && entry.artist == playing.artist;
  }

  @override
  Widget build(BuildContext context) {
    return HMusicTrackRow(
      leading: _ChartRank(rank: entry.rank, playing: _isPlaying),
      coverUrl: entry.coverUrl,
      title: entry.title,
      subtitle: entry.artist,
      subtitleAccent: entry.playCount != null
          ? ' · ${entry.playCount} 次'
          : null,
      showDivider: showDivider,
      onTap: enabled ? () => notifier.play(entry) : null,
      actions: <Widget>[
        if (downloadsEnabled) ...[
          if (archiving)
            SizedBox.square(
              dimension: 44,
              child: Center(
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.palette.mutedStrong,
                  ),
                ),
              ),
            )
          else
            HMusicIconButton(
              icon: archived
                  ? Icons.download_done_rounded
                  : Icons.download_rounded,
              tooltip: archived ? '已入库' : '下载到服务器',
              onPressed: archived || !enabled
                  ? null
                  : () => notifier.download(entry),
            ),
        ],
        if (enabled)
          HMusicConfirmButton(
            icon: Icons.add_rounded,
            tooltip: '加入队列',
            onAction: () => notifier.enqueue(entry),
          )
        else
          const HMusicIconButton(
            icon: Icons.add_rounded,
            tooltip: '加入队列',
            onPressed: null,
          ),
      ],
    );
  }
}

class _ChartRank extends StatelessWidget {
  const _ChartRank({required this.rank, required this.playing});

  final int rank;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final top = rank <= 3;
    return SizedBox(
      width: 28,
      child: playing
          ? Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 18,
                color: palette.accent,
              ),
            )
          : Text(
              '$rank',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: top ? 'NotoSerifSC' : null,
                fontSize: top ? 17 : 14,
                fontWeight: top ? FontWeight.w700 : FontWeight.normal,
                color: top ? palette.textStrong : palette.muted,
              ),
            ),
    );
  }
}
