import 'package:flutter/material.dart';

import '../../../core/downloads/download_index.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';

// 搜索结果列表：复用全站曲目行原子（对齐 web search.js 的 track-row 列表，无外层
// 卡片）。交互与榜单行一致——点整行即播放（不另出播放钮），行尾只留入库与队列
// 两个附加动作；入库位三态同宽：↓ / 菊花 / 灰对勾。
class SearchResultList extends StatelessWidget {
  const SearchResultList({
    required this.tracks,
    required this.playingTrackId,
    required this.archive,
    required this.onPlay,
    required this.onEnqueue,
    required this.onDownload,
    super.key,
  });

  final List<HMusicTrack> tracks;

  // 正在起播的那首（防连点：起播期间行尾动作与行点击都收起）。
  final String? playingTrackId;

  // 入库索引（与榜单页同一份，见 core/downloads/download_index.dart）。
  final DownloadIndex archive;

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
    final idle = playingTrackId == null;
    final archived = archive.isArchived(track);
    final archiving = archive.isArchiving(track);
    return HMusicTrackRow(
      coverUrl: track.coverUrl,
      title: track.title,
      contentPadding: const EdgeInsets.only(top: 10, right: 12, bottom: 10),
      subtitle: <String>[
        track.artist,
        if (track.album != null && track.album!.isNotEmpty) track.album!,
      ].join(' · '),
      showDivider: showDivider,
      onTap: idle ? () => onPlay(track) : null,
      actions: <Widget>[
        if (archiving)
          const _ArchivingSpinner()
        else
          HMusicIconButton(
            icon: archived
                ? Icons.download_done_rounded
                : Icons.download_rounded,
            tooltip: archived ? '已入库' : '下载到服务器',
            onPressed: archived || !idle ? null : () => onDownload(track),
          ),
        HMusicIconButton(
          icon: Icons.add_rounded,
          tooltip: '加入队列',
          onPressed: idle ? () => onEnqueue(track) : null,
        ),
      ],
    );
  }
}

// 排队/下载中：占位与图标钮同宽，行尾不因状态切换而漂移。
class _ArchivingSpinner extends StatelessWidget {
  const _ArchivingSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 34,
      child: Center(
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
