import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/downloads/download_index.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../player/view_models/player_view_model.dart';
import '../models/chart.dart';
import '../view_models/charts_view_model.dart';
import 'chart_detail_header.dart';
import 'chart_detail_track_row.dart';

// 榜单详情：返回 + 播放全部 + 曲目列表。点行即播（行尾只留入库/队列两个附加
// 动作，入库位三态同宽：↓ / 菊花 / 灰对勾）。前 3 名排名用衬线加深墨（对齐
// .chart-rank.top），播放次数用青绿计数（.chart-count，全站唯一表达「正在发生
// 的事」外的青绿例外）。
class ChartDetailView extends ConsumerWidget {
  const ChartDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chartsViewModelProvider);
    final notifier = ref.read(chartsViewModelProvider.notifier);
    final active = state.active;
    if (active == null) return const SizedBox.shrink();

    final detail = state.detail;
    final entries = detail?.entries ?? const <ChartEntry>[];
    // 当前播放曲目（榜内行标识用）：优先 track.id 精确匹配（带快照的榜）；
    // Apple 榜条目经搜索匹配后 id 对不上，退回「歌名 + 歌手」相等。
    final playingTrack = ref.watch(
      serverPlaybackStateProvider.select((s) => s.value?.track),
    );
    // 行尾入库位的三态由共享索引决定（搜索页同源）。
    ref.watch(downloadIndexProvider);
    final archive = ref.read(downloadIndexProvider.notifier);

    // 头部（返回/播放全部/榜名/简介）+ 加载/空态占位；曲目行走 builder 懒建，
    // 100+ 行的榜首帧不再全量 build。加载中不出旧榜的行（与旧全量分支语义一致）。
    final rows = state.detailLoading ? const <ChartEntry>[] : entries;
    return ListView.builder(
      // 水平只留 4：曲目行自带 12 内边距（hover/ink 出血位），4+12=16 使行内
      // 排名数字左缘与页头/标题同压 16 基线（红线验收：返回/榜名/排名一条线）。
      // 头部文字块自行补 12。底部累加环境 padding：iOS 26+ 原生 dock 悬浮时
      // 让出 chrome 高度（Flutter 壳下为 0）。
      padding: EdgeInsets.fromLTRB(
        4,
        12 + MediaQuery.paddingOf(context).top,
        4,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: 1 + rows.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ChartDetailHeader(
            state: state,
            notifier: notifier,
            chart: active,
            hasEntries: entries.isNotEmpty,
          );
        }
        final i = index - 1;
        final entry = rows[i];
        return ChartDetailTrackRow(
          entry: entry,
          downloadsEnabled:
              ref.watch(playbackModeProvider) == PlaybackMode.server,
          playingTrack: playingTrack,
          notifier: notifier,
          archived: archive.isArchived(entry.track),
          archiving: archive.isArchiving(entry.track),
          enabled: state.actingRank == 0,
          showDivider: i != rows.length - 1,
        );
      },
    );
  }
}
