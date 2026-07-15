import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/chart.dart';
import '../view_models/charts_view_model.dart';

// 榜单详情：返回 + 播放全部 + 曲目列表。前 3 名排名用衬线加深墨（对齐 .chart-rank.top），
// 播放次数用青绿计数（.chart-count，全站唯一表达「正在发生的事」外的青绿例外）。
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TextButton(onPressed: notifier.back, child: const Text('‹ 返回')),
            if (detail?.hasPlayableEntries ?? false)
              OutlinedButton(
                onPressed: state.actingRank == 0 ? notifier.playAll : null,
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
          for (var i = 0; i < entries.length; i++)
            HMusicTrackRow(
              leading: _ChartRank(rank: entries[i].rank),
              coverUrl: entries[i].coverUrl,
              title: entries[i].title,
              subtitle: entries[i].artist,
              subtitleAccent: entries[i].playCount != null
                  ? ' · ${entries[i].playCount} 次'
                  : null,
              showDivider: i != entries.length - 1,
              actions: <Widget>[
                HMusicIconButton(
                  icon: Icons.play_arrow_rounded,
                  tooltip: '播放',
                  onPressed: state.actingRank == 0
                      ? () => notifier.play(entries[i])
                      : null,
                ),
                HMusicIconButton(
                  icon: Icons.add_rounded,
                  tooltip: '加入队列',
                  onPressed: state.actingRank == 0
                      ? () => notifier.enqueue(entries[i])
                      : null,
                ),
              ],
            ),
      ],
    );
  }
}

// 榜单排名：前 3 名衬线加深墨（.chart-rank.top），其余弱化数字。
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
        textAlign: TextAlign.center,
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
