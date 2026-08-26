import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../../../shared/widgets/hmusic_dialog.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/playlist.dart';
import '../models/playlists_view_state.dart';
import '../view_models/playlists_view_model.dart';
import 'playlist_card.dart';
import 'playlist_input_dialog.dart';

// 歌单列表：页头（导入/创建）+ 卡片网格（对齐 web .playlist-grid，窄屏单列）。
class PlaylistsListView extends ConsumerWidget {
  const PlaylistsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(playlistsViewModelProvider);
    final notifier = ref.read(playlistsViewModelProvider.notifier);

    // 下拉刷新重拉歌单列表（docs/05 列表下拉手势）。
    return RefreshIndicator.adaptive(
      onRefresh: notifier.loadList,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // 底部累加环境 padding：iOS 26+ 原生 dock 悬浮时让出 chrome 高度（Flutter 壳下为 0）。
        padding: EdgeInsets.fromLTRB(
          16,
          24 + MediaQuery.paddingOf(context).top,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const ViewTitle('歌单'),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => _import(context, notifier),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('导入'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => _create(context, notifier),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('创建'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          // 系统视图入口（对齐 Apple Music「资料库」心智）：同页切换、不占底栏 tab。
          _LibraryEntry(onOpen: notifier.openLibrary),
          const SizedBox(height: 18),
          if (state.status == PlaylistsStatus.loading &&
              state.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.status == PlaylistsStatus.error &&
              state.playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  state.errorMessage ?? '歌单加载失败',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            )
          else if (state.playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  '还没有歌单，创建一个吧',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            )
          else
            _grid(context, state, notifier),
        ],
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    PlaylistsViewState state,
    PlaylistsViewModel notifier,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 312).floor().clamp(1, 3);
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final playlist in state.playlists)
              SizedBox(
                width: columns == 1 ? constraints.maxWidth : width,
                child: PlaylistCard(
                  playlist: playlist,
                  onOpen: () => notifier.openPlaylist(playlist.id),
                  onPlay: () => notifier.playAll(playlist.id),
                  onDelete: () => _confirmDelete(context, notifier, playlist),
                ),
              ),
          ],
        );
      },
    );
  }

  // 删整单不可恢复，先确认（导入 500 首的单误触一下就没了太伤）。
  Future<void> _confirmDelete(
    BuildContext context,
    PlaylistsViewModel notifier,
    PlaylistSummary playlist,
  ) async {
    final ok = await showHMusicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text(
          '确定删除「${playlist.name}」吗？共 ${playlist.trackCount} 首，删除后无法恢复。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok ?? false) await notifier.deletePlaylist(playlist.id);
  }

  Future<void> _create(
    BuildContext context,
    PlaylistsViewModel notifier,
  ) async {
    final name = await showHMusicDialog<String>(
      context: context,
      builder: (_) => const PlaylistInputDialog(
        title: '创建歌单',
        hint: '新歌单名称…',
        confirmLabel: '创建',
      ),
    );
    if (name != null && name.isNotEmpty) await notifier.create(name);
  }

  Future<void> _import(
    BuildContext context,
    PlaylistsViewModel notifier,
  ) async {
    final url = await showHMusicDialog<String>(
      context: context,
      builder: (_) => const PlaylistInputDialog(
        title: '导入歌单',
        hint: '粘贴歌单链接或整段分享文案…',
        confirmLabel: '开始导入',
        helper: '粘贴 QQ音乐 / 酷我 / 网易云 的歌单分享链接，最多导入 500 首。',
        multiline: true,
      ),
    );
    if (url != null && url.isNotEmpty) await notifier.import(url);
  }
}

// NAS 曲库系统视图入口行：常驻歌单列表顶部，点击 push 曲库页。
class _LibraryEntry extends StatelessWidget {
  const _LibraryEntry({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HMusicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Icon(Icons.dns_rounded, size: 20, color: palette.muted),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'NAS 曲库',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: palette.muted),
        ],
      ),
    );
  }
}
