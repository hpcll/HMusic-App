import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_adaptive_track_row.dart';
import '../../../shared/widgets/hmusic_confirm_button.dart';
import '../../../shared/widgets/hmusic_track_table_header.dart';
import '../models/library_item.dart';
import '../models/library_view_state.dart';
import '../view_models/library_view_model.dart';

// 仅构建可见曲目，刷新和分页由外层统一滚动区触发。
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
    if (state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Center(
            child: state.isLoading
                ? const CircularProgressIndicator()
                : Text(
                    state.query.isEmpty
                        ? '曲库是空的——扫描 NAS 音乐目录，\n或在搜索页把歌下载到服务器'
                        : '没有匹配「${state.query}」的曲目',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.palette.muted),
                  ),
          ),
        ),
      );
    }
    return SliverPadding(
      // 水平 4 + 行自带 12 = 16 基线，与页头同轨。
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList.builder(
        itemCount: state.items.length + 1 + (state.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const HMusicTrackTableHeader(actionsWidth: 44);
          }
          if (index > state.items.length) {
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
          return _row(state.items[index - 1], index == state.items.length);
        },
      ),
    );
  }

  Widget _row(LibraryItem item, bool isLast) {
    final busy = state.playingTrackId == item.track.id;
    return HMusicAdaptiveTrackRow(
      key: ValueKey(item.id),
      track: item.track,
      actionsWidth: 44,
      showDivider: !isLast,
      onTap: busy ? null : () => notifier.play(item.track),
      actions: <Widget>[
        if (busy)
          const SizedBox.square(
            dimension: 44,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          HMusicConfirmButton(
            icon: Icons.playlist_add_rounded,
            tooltip: '加入队列',
            onAction: () => notifier.enqueue(item.track),
          ),
      ],
    );
  }
}
