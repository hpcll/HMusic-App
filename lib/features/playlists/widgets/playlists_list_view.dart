import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/hmusic_inline_notice.dart';
import '../../../shared/widgets/view_title.dart';
import '../view_models/playlists_view_model.dart';
import 'playlist_dialog_actions.dart';
import 'playlists_collection.dart';

// 可嵌入的歌单根内容；创建/导入与错误反馈随根分段显示。
class PlaylistsListView extends ConsumerWidget {
  const PlaylistsListView({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistsViewModelProvider);
    final notifier = ref.read(playlistsViewModelProvider.notifier);
    return RefreshIndicator.adaptive(
      onRefresh: notifier.loadList,
      child: ListView(
        key: const PageStorageKey<String>('playlists-list'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          embedded ? 0 : 24 + MediaQuery.paddingOf(context).top,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          if (!embedded) ...<Widget>[
            const ViewTitle('歌单'),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : () => showCreatePlaylistDialog(context, notifier),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('创建歌单'),
              ),
              OutlinedButton.icon(
                onPressed: state.busy
                    ? null
                    : () => showImportPlaylistDialog(context, notifier),
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: const Text('导入'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (state.errorMessage != null) ...<Widget>[
            HMusicInlineNotice(HMusicNotice.error(state.errorMessage!)),
            const SizedBox(height: 12),
          ],
          if (state.notice != null) ...<Widget>[
            HMusicInlineNotice(state.notice!),
            const SizedBox(height: 12),
          ],
          PlaylistsCollection(state: state, notifier: notifier),
        ],
      ),
    );
  }
}
