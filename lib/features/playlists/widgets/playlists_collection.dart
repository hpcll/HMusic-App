import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/playlists_view_state.dart';
import '../view_models/playlists_view_model.dart';
import 'playlist_card.dart';
import 'playlist_dialog_actions.dart';

class PlaylistsCollection extends StatelessWidget {
  const PlaylistsCollection({
    required this.state,
    required this.notifier,
    super.key,
  });

  final PlaylistsViewState state;
  final PlaylistsViewModel notifier;

  @override
  Widget build(BuildContext context) {
    if (state.status == PlaylistsStatus.loading && state.playlists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.playlists.isEmpty) return _empty(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = (constraints.maxWidth / (300 * scale)).floor().clamp(
          1,
          4,
        );
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final playlist in state.playlists)
              SizedBox(
                width: width,
                child: PlaylistCard(
                  key: ValueKey(playlist.id),
                  playlist: playlist,
                  enabled: !state.busy,
                  onOpen: () => notifier.openPlaylist(playlist.id),
                  onPlay: () => notifier.playAll(playlist.id),
                  onDelete: () =>
                      confirmDeletePlaylist(context, notifier, playlist),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final failed = state.status == PlaylistsStatus.error;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: <Widget>[
          Text(
            failed ? '暂时无法读取歌单' : '还没有歌单',
            style: TextStyle(color: context.palette.muted),
          ),
          const SizedBox(height: 12),
          if (failed)
            OutlinedButton(
              onPressed: notifier.loadList,
              child: const Text('重新加载'),
            )
          else
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => showCreatePlaylistDialog(context, notifier),
              child: const Text('创建第一个歌单'),
            ),
        ],
      ),
    );
  }
}
