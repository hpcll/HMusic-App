import 'package:flutter/material.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';

// 搜索结果列表：复用全站曲目行原子（对齐 web search.js 的 track-row 列表，无外层卡片）。
class SearchResultList extends StatelessWidget {
  const SearchResultList({
    required this.tracks,
    required this.playingTrackId,
    required this.onPlay,
    required this.onEnqueue,
    required this.onDownload,
    super.key,
  });

  final List<HMusicTrack> tracks;
  final String? playingTrackId;
  final ValueChanged<HMusicTrack> onPlay;
  final ValueChanged<HMusicTrack> onEnqueue;
  final ValueChanged<HMusicTrack> onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < tracks.length; i++)
          _row(tracks[i], showDivider: i != tracks.length - 1),
      ],
    );
  }

  Widget _row(HMusicTrack track, {required bool showDivider}) {
    final loading = playingTrackId == track.id;
    return HMusicTrackRow(
      coverUrl: track.coverUrl,
      title: track.title,
      contentPadding: const EdgeInsets.only(top: 10, right: 12, bottom: 10),
      subtitle: <String>[
        track.artist,
        if (track.album != null && track.album!.isNotEmpty) track.album!,
      ].join(' · '),
      showDivider: showDivider,
      actions: <Widget>[
        HMusicIconButton(
          icon: Icons.download_rounded,
          tooltip: '下载到服务器',
          onPressed: () => onDownload(track),
        ),
        HMusicIconButton(
          icon: Icons.add_rounded,
          tooltip: '加入队列',
          onPressed: () => onEnqueue(track),
        ),
        if (loading)
          const SizedBox.square(
            dimension: 34,
            child: Center(
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          HMusicIconButton(
            icon: Icons.play_arrow_rounded,
            tooltip: '播放',
            onPressed: () => onPlay(track),
          ),
      ],
    );
  }
}
