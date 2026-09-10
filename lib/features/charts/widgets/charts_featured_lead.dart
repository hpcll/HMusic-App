import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../models/chart.dart';
import 'chart_preview_song.dart';

// 桌面主推卡在网格内自然增高；封面保持方形，Top3 的歌名与歌手分层。
class ChartsFeaturedLead extends StatelessWidget {
  const ChartsFeaturedLead({
    required this.chart,
    required this.entries,
    required this.sourceLabel,
    required this.onOpen,
    super.key,
  });

  final Chart chart;
  final List<ChartEntry> entries;
  final String sourceLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HMusicCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          HMusicCover(
            url: entries.isNotEmpty ? entries.first.coverUrl : null,
            size: 112,
            radius: 10,
            iconSize: 30,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$sourceLabel · 每日更新',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  chart.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 20,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  Text(
                    chart.description ?? '暂无榜单曲目',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: palette.muted),
                  )
                else
                  for (final entry in entries.take(3))
                    ChartPreviewSong(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
