import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_track_row.dart';
import '../models/library_item.dart';
import '../models/library_view_state.dart';
import '../view_models/library_view_model.dart';

// 上传进度条（当前文件名 + 剩余计数）。
class LibraryUploadBanner extends StatelessWidget {
  const LibraryUploadBanner({required this.state, super.key});

  final LibraryViewState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            state.uploadRemaining > 0
                ? '正在上传 ${state.uploadingName}（还剩 ${state.uploadRemaining} 个）'
                : '正在上传 ${state.uploadingName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: context.palette.muted),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: state.uploadProgress <= 0 ? null : state.uploadProgress,
          ),
        ],
      ),
    );
  }
}

// 曲库搜索框：panel 底 + line 细边圆角，对齐站内胶囊语言（不是 Material 灰框）。
class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '搜索曲库…',
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: palette.muted),
        isDense: true,
        filled: true,
        fillColor: palette.panel,
        enabledBorder: border(palette.line),
        focusedBorder: border(Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

// 曲库列表主体：下拉刷新 + 滚动到底翻页 + 空态（可下拉）。
class LibraryTrackList extends StatelessWidget {
  const LibraryTrackList({
    required this.state,
    required this.notifier,
    super.key,
  });

  final LibraryViewState state;
  final LibraryViewModel notifier;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final Widget list;
    if (state.items.isEmpty) {
      list = LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Text(
                  state.query.isEmpty
                      ? '曲库是空的——扫描 NAS 音乐目录，\n或在搜索页把歌下载到服务器'
                      : '没有匹配「${state.query}」的曲目',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.muted),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      list = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) {
            unawaited(notifier.loadMore());
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          // 水平 4 + 行自带 12 = 16 基线（与页头同轨，playlist 详情同款）。
          padding: EdgeInsets.fromLTRB(
            4,
            0,
            4,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: state.items.length + (state.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return _row(state.items[index], index == state.items.length - 1);
          },
        ),
      );
    }
    return RefreshIndicator.adaptive(
      onRefresh: () => notifier.load(),
      child: list,
    );
  }

  Widget _row(LibraryItem item, bool isLast) {
    final busy = state.playingTrackId == item.track.id;
    final artistAlbum = item.album == null || item.album!.isEmpty
        ? item.artist
        : '${item.artist} · ${item.album}';
    return HMusicTrackRow(
      coverUrl: item.coverUrl,
      title: item.title,
      subtitle: artistAlbum.isEmpty ? '未知歌手' : artistAlbum,
      showDivider: !isLast,
      onTap: busy ? null : () => notifier.play(item.track),
      actions: <Widget>[
        if (busy)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            tooltip: '加入队列',
            onPressed: () => notifier.enqueue(item.track),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
      ],
    );
  }
}
