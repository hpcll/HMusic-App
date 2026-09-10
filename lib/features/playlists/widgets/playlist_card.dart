import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../../../shared/widgets/hmusic_collection_artwork.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../models/playlist.dart';

// 歌单封面与名称优先；管理操作收在更多菜单，实际删除仍由上层确认。
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    required this.playlist,
    required this.onOpen,
    required this.onPlay,
    required this.onDelete,
    this.enabled = true,
    super.key,
  });

  final PlaylistSummary playlist;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = playlist.name.trim().isEmpty ? '未命名歌单' : playlist.name;
    return HMusicCard(
      padding: const EdgeInsets.all(14),
      onTap: enabled ? onOpen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              HMusicCollectionArtwork(identity: playlist.id, label: name),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: palette.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${playlist.trackCount} 首',
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
              ),
              HMusicIconButton(
                icon: Icons.play_arrow_rounded,
                tooltip: '播放歌单',
                onPressed: enabled && playlist.trackCount > 0 ? onPlay : null,
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作：$name',
                enabled: enabled,
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                constraints: const BoxConstraints(minWidth: 160),
                onSelected: (_) => onDelete(),
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      '删除歌单',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
