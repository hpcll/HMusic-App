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
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
    return SizedBox(
      width: 28,
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
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
