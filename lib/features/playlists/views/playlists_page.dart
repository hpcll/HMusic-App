import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/hmusic_toast.dart';
import '../../library/view_models/library_view_model.dart';
import '../../library/widgets/library_view.dart';
import '../view_models/playlists_view_model.dart';
import '../widgets/playlist_detail_view.dart';
import '../widgets/playlists_list_view.dart';

// 歌单页（底栏 tab 分支内容）：列表 ↔ 详情 ↔ NAS 曲库三态同页切换，
// 对齐 web playlists.js 的系统视图心智——壳的 dock/侧栏全程常驻。
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
    final state = ref.watch(playlistsViewModelProvider);
    // 详情/曲库都是页内二级态：系统返回逐层收回（曲库内先退组，再退曲库），
    // 不冒泡到壳层。
    return PopScope(
      canPop: state.isList,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final notifier = ref.read(playlistsViewModelProvider.notifier);
        if (state.detail != null) {
          unawaited(notifier.backToList());
          return;
        }
        final library = ref.read(libraryViewModelProvider);
        if (library.activeGroup != null) {
          ref.read(libraryViewModelProvider.notifier).closeGroup();
          return;
        }
        notifier.closeLibrary();
      },
      child: state.detail != null
          ? const PlaylistDetailView()
          : state.libraryOpen
          ? LibraryView(
              onBack: ref
                  .read(playlistsViewModelProvider.notifier)
                  .closeLibrary,
            )
          : const PlaylistsListView(),
    );
  }
}
