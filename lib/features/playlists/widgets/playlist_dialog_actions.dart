import 'package:flutter/material.dart';

import '../../../shared/widgets/hmusic_dialog.dart';
import '../models/playlist.dart';
import '../view_models/playlists_view_model.dart';
import 'playlist_input_dialog.dart';

Future<void> showCreatePlaylistDialog(
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

Future<void> showImportPlaylistDialog(
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

// 删除入口收在更多菜单中，实际请求仍须经过确认。
Future<void> confirmDeletePlaylist(
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
