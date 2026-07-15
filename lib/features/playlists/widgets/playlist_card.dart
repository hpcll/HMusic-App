import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../models/playlist.dart';

// 歌单卡片，对齐 web .playlist-card：44 图标 + 名称/N首 + 播放/删除操作。
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    required this.playlist,
    required this.onOpen,
    required this.onPlay,
    required this.onDelete,
    super.key,
  });

  final PlaylistSummary playlist;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HMusicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.panelSecondary,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: palette.lineSoft),
            ),
            child: Icon(
              Icons.library_music_rounded,
              size: 20,
              color: palette.textStrong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${playlist.trackCount} 首',
                  style: TextStyle(fontSize: 13.5, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HMusicIconButton(
            icon: Icons.play_arrow_rounded,
            tooltip: '播放',
            onPressed: onPlay,
          ),
          const SizedBox(width: 6),
          HMusicIconButton(
            icon: Icons.close_rounded,
            tooltip: '删除',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
