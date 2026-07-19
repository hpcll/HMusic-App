import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/hmusic_toast.dart';
import '../view_models/playlists_view_model.dart';
import '../widgets/playlist_detail_view.dart';
import '../widgets/playlists_list_view.dart';

// 歌单页（底栏 tab 分支内容）：列表 ↔ 详情同页切换，对齐 web playlists.js。
// 「已下载」系统视图依赖 downloads（P2），本里程碑先不做。
class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  static const String path = '/playlists';

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(playlistsViewModelProvider.notifier).loadList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playlistsViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showHMusicToast(context, notice);
      ref.read(playlistsViewModelProvider.notifier).clearNotice();
    });
    final isList = ref.watch(
      playlistsViewModelProvider.select((s) => s.isList),
    );
    // 详情是页内二级态：系统返回先收回列表（并刷新曲目数），不冒泡到壳层。
    return PopScope(
      canPop: isList,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(ref.read(playlistsViewModelProvider.notifier).backToList());
      },
      child: isList ? const PlaylistsListView() : const PlaylistDetailView(),
    );
  }
}
