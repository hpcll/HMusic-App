import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/playlists_view_model.dart';
import '../widgets/playlist_detail_view.dart';
import '../widgets/playlists_list_view.dart';

// 歌单列表与详情；曲库根分段由 app 层组合，本 feature 不持有 NAS 状态。
class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({this.embedded = false, super.key});

  final bool embedded;

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
    final state = ref.watch(playlistsViewModelProvider);
    // 嵌入曲库时由组合页处理当前分段的返回，避免隐藏页拦截系统返回。
    return PopScope(
      canPop: widget.embedded || state.isList,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.embedded) return;
        unawaited(ref.read(playlistsViewModelProvider.notifier).backToList());
      },
      child: state.detail != null
          ? const PlaylistDetailView()
          : PlaylistsListView(embedded: widget.embedded),
    );
  }
}
