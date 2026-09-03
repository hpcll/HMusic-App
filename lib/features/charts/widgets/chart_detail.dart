import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../shared/widgets/back_link.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';
import '../../../shared/widgets/view_title.dart';
import '../../player/view_models/player_view_model.dart';
import '../../settings/models/download_record.dart';
import '../models/chart.dart';
import '../view_models/charts_view_model.dart';

// 榜单详情：返回 + 播放全部 + 曲目列表。点行即播（行尾只留入库/队列两个附加
// 动作，入库位三态同宽：↓ / 菊花 / 灰对勾）。前 3 名排名用衬线加深墨（对齐
// .chart-rank.top），播放次数用青绿计数（.chart-count，全站唯一表达「正在发生
// 的事」外的青绿例外）。
class ChartDetailView extends ConsumerWidget {
  const ChartDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
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

    // 头部（返回/播放全部/榜名/简介）+ 加载/空态占位；曲目行走 builder 懒建，
    // 100+ 行的榜首帧不再全量 build。加载中不出旧榜的行（与旧全量分支语义一致）。
    final rows = state.detailLoading ? const <ChartEntry>[] : entries;
    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  BackLink(label: '返回', onTap: notifier.back),
                  // Apple 榜条目无 track 快照也能整榜播放（服务端搜索匹配），
                  // 只要榜单有条目就给按钮。
                  if (entries.isNotEmpty)
                    OutlinedButton(
                      onPressed: state.actingRank == 0
                          ? notifier.playAll
                          : null,
                      child: const Text('播放全部'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ViewTitle(active.name),
              if (active.description != null &&
                  active.description!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  active.description!,
                  style: TextStyle(fontSize: 13.5, color: palette.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.detailLoading)
          const Padding(
            padding: EdgeInsets.only(top: 36),
            child: Center(child: Text('榜单加载中…')),
          )
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: Center(
              child: Text(
                active.id == 'family' ? '还没有播放记录，放几首歌就有家庭热播榜了' : '榜单是空的',
                style: TextStyle(color: palette.muted),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );

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
        if (index == 0) return header;
        final i = index - 1;
        final entry = rows[i];
        final idle = state.actingRank == 0;
        // 入库状态：已完成的行给标题挂角标、不再出下载钮；排队/下载中转菊花。
        final key = chartEntryTrackKey(entry);
        final archive = key == null ? null : state.downloads[key];
        final archived = archive == DownloadStatus.done;
        final archiving =
            archive == DownloadStatus.pending ||
            archive == DownloadStatus.downloading;
        return HMusicTrackRow(
          leading: _isEntryPlaying(entry, playingTrack)
              ? const _PlayingRank()
              : _ChartRank(rank: entry.rank),
          coverUrl: entry.coverUrl,
          title: entry.title,
          subtitle: entry.artist,
          subtitleAccent: entry.playCount != null
              ? ' · ${entry.playCount} 次'
              : null,
          showDivider: i != rows.length - 1,
          // 整行即播放键：点哪一行放哪一首（不再另出播放钮，行尾只留入库与
          // 队列这两个「附加动作」）。
          onTap: idle ? () => notifier.play(entry) : null,
          actions: <Widget>[
            // 入库位恒在行尾同一格：没入库是 ↓、下载中转菊花、已入库是灰掉的
            // 对勾——三态同宽，切换时右侧的队列钮不会横向漂移。
            if (archiving)
              const _ArchivingSpinner()
            else
              HMusicIconButton(
                icon: archived
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                tooltip: archived ? '已入库' : '下载到服务器',
                onPressed: archived || !idle
                    ? null
                    : () => notifier.download(entry),
              ),
            HMusicIconButton(
              icon: Icons.add_rounded,
              tooltip: '加入队列',
              onPressed: idle ? () => notifier.enqueue(entry) : null,
            ),
          ],
        );
      },
    );
  }
}

// 排队/下载中：占位与图标钮同宽，行尾不因状态切换而漂移。
class _ArchivingSpinner extends StatelessWidget {
  const _ArchivingSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: Center(
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.palette.mutedStrong,
          ),
        ),
      ),
    );
  }
}

// 榜单排名：前 3 名衬线加深墨（.chart-rank.top），其余弱化数字。
// 左对齐：数字左缘全部压在页面 16 基线上（与返回/榜名一条左轨），
// 固定宽度保证 1/10/100 位数不同的行封面列不漂移。
class _ChartRank extends StatelessWidget {
  const _ChartRank({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final top = rank <= 3;
    return SizedBox(
      width: 28,
      child: Text(
        '$rank',
        textAlign: TextAlign.left,
        style: top
            ? TextStyle(
                fontFamily: 'NotoSerifSC',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.textStrong,
              )
            : TextStyle(fontSize: 14, color: palette.muted),
      ),
    );
  }
}

// 条目是否为当前播放曲目：带 track 快照按 id 精确匹配；Apple 榜条目经搜索
// 匹配后 id 对不上，退回「歌名 + 歌手」相等（对不上就不标，尽力而为）。
bool _isEntryPlaying(ChartEntry entry, HMusicTrack? playing) {
  if (playing == null) return false;
  final track = entry.track;
  if (track != null) return track.id == playing.id;
  return entry.title == playing.title && entry.artist == playing.artist;
}

// 排名位的「正在播放」标识：青绿均衡器图标（青绿=全站「正在发生的事」语义，
// 同 .chart-count），占位宽度与排名一致，封面列不漂移。
class _PlayingRank extends StatelessWidget {
  const _PlayingRank();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Icon(
          Icons.graphic_eq_rounded,
          size: 18,
          color: context.palette.accent,
        ),
      ),
    );
  }
}
