import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';
import '../models/stats.dart';

// Top 歌曲卡：复用曲目行原子，前 3 名衬线排名、青绿播放次数，可点播（缺 track 禁用）。
class StatTopTracksCard extends StatelessWidget {
  const StatTopTracksCard({
    required this.tracks,
    required this.actingKey,
    required this.onPlay,
    super.key,
  });

  final List<TrackStat> tracks;
  final String actingKey;
  final void Function(TrackStat item) onPlay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (tracks.isEmpty) return const SizedBox.shrink();
    return HMusicCard(
      // 左 8：曲目行自带 12 内边距（ink 出血位），8+12=20 使行内排名与卡题
      // 同压 20 基线（卡内左轨一条线）；卡题自行补 12。
      padding: const EdgeInsets.fromLTRB(8, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Text(
              '最常播放 Top 10',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: palette.textStrong,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < tracks.length; i++)
            _row(context, tracks[i], i, i == tracks.length - 1),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, TrackStat item, int index, bool isLast) {
    final busy = actingKey == item.key;
    final playable = item.track != null;
    final row = HMusicTrackRow(
      leading: _Rank(rank: index + 1),
      coverUrl: item.coverUrl,
      title: item.title,
      subtitle: item.artist,
      subtitleAccent: ' · ${item.playCount} 次',
      showDivider: !isLast,
      actions: <Widget>[
        HMusicIconButton(
          icon: Icons.play_arrow_rounded,
          tooltip: playable ? '播放' : '无法播放',
          onPressed: !playable || busy ? null : () => onPlay(item),
        ),
      ],
    );
    // 无 track 的行整体弱化，观感对齐 web disabled。
    return playable ? row : Opacity(opacity: 0.55, child: row);
  }
}

class _Rank extends StatelessWidget {
  const _Rank({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final top = rank <= 3;
    // 左对齐：排名与卡题一条左轨，定宽保证 1/10 位数不同的行封面列不漂移。
    return SizedBox(
      width: 28,
      child: Text(
        '$rank',
        textAlign: TextAlign.left,
        style: top
            ? TextStyle(
                fontFamily: 'NotoSerifSC',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.textStrong,
              )
            : TextStyle(fontSize: 14, color: palette.muted),
      ),
    );
  }
}
