import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/playlist.dart';
import '../view_models/playlists_view_model.dart';

// 歌单详情：返回 + 播放全部 + 曲目列表。点曲目行从该首整单播放；尾部移除键按条删。
class PlaylistDetailView extends ConsumerWidget {
  const PlaylistDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(playlistsViewModelProvider);
    final notifier = ref.read(playlistsViewModelProvider.notifier);
    final detail = state.detail;
    if (detail == null) return const SizedBox.shrink();

    final items = detail.items;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TextButton(
              onPressed: notifier.backToList,
              child: const Text('‹ 返回'),
            ),
            OutlinedButton(
              onPressed: items.isEmpty || state.busy
                  ? null
                  : () => notifier.playAll(detail.id),
              child: const Text('播放全部'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ViewTitle(detail.name),
        if (detail.description != null &&
            detail.description!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            detail.description!,
            style: TextStyle(fontSize: 13.5, color: palette.muted),
          ),
        ],
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: Center(
              child: Text(
                '歌单是空的，在搜索里加歌到队列或歌单',
                style: TextStyle(color: palette.muted),
              ),
            ),
          )
        else
          for (var i = 0; i < items.length; i++)
            _row(context, notifier, detail, items[i], i, i == items.length - 1),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    PlaylistsViewModel notifier,
    PlaylistDetail detail,
    PlaylistItem item,
    int index,
    bool isLast,
  ) {
    final palette = context.palette;
    return HMusicTrackRow(
      leading: SizedBox(
        width: 28,
        child: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: palette.muted),
        ),
      ),
      coverUrl: item.track.coverUrl,
      title: item.track.title,
      subtitle: item.track.artist.isEmpty ? '未知' : item.track.artist,
      showDivider: !isLast,
      onTap: () => notifier.playAll(detail.id, startIndex: index),
      actions: <Widget>[
        HMusicIconButton(
          icon: Icons.close_rounded,
          tooltip: '从歌单移除',
          onPressed: () => notifier.removeItem(item.id),
        ),
      ],
    );
  }
}
