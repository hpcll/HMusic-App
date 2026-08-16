import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_toast.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/stats.dart';
import '../models/stats_view_state.dart';
import '../view_models/stats_view_model.dart';
import '../widgets/stat_bars_card.dart';
import '../widgets/stat_chart_cards.dart';
import '../widgets/stat_overview_grid.dart';
import '../widgets/stat_top_tracks_card.dart';

// 统计页（底栏 tab 分支内容）：4 数字卡 → 趋势 → 时段 → 来源 → Top 艺术家/歌曲/专辑。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  static const String path = '/stats';

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(statsViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    ref.listen(statsViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showHMusicToast(context, notice);
      ref.read(statsViewModelProvider.notifier).clearNotice();
    });
    final state = ref.watch(statsViewModelProvider);

    // 下拉刷新重拉统计（docs/05 列表下拉手势）。
    return RefreshIndicator.adaptive(
      onRefresh: ref.read(statsViewModelProvider.notifier).load,
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
          const ViewTitle('听歌统计'),
          const SizedBox(height: 22),
          ..._content(context, state, palette),
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    StatsViewState state,
    HMusicPalette palette,
  ) {
    if (state.status == StatsStatus.loading && state.stats == null) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.status == StatsStatus.error && state.stats == null) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: Text(
              state.errorMessage ?? '统计加载失败',
              style: TextStyle(color: palette.muted),
            ),
          ),
        ),
      ];
    }
    final stats = state.stats;
    if (stats == null || stats.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: Text(
              '还没有听歌记录，放几首歌这里就热闹了',
              style: TextStyle(color: palette.muted),
            ),
          ),
        ),
      ];
    }
    return _cards(stats, state.actingKey);
  }

  List<Widget> _cards(Stats stats, String actingKey) {
    return <Widget>[
      StatOverviewGrid(overview: stats.overview, last30d: stats.last30d),
      const SizedBox(height: 12),
      TrendCard(daily: stats.dailyTrend),
      const SizedBox(height: 12),
      HoursCard(hours: stats.hourDist),
      const SizedBox(height: 12),
      SourcesCard(sources: stats.sourceDist),
      const SizedBox(height: 12),
      StatBarsCard(
        title: '常听艺术家 Top 10',
        rows: <({String name, int value})>[
          for (final a in stats.topArtists) (name: a.name, value: a.playCount),
        ],
      ),
      const SizedBox(height: 12),
      StatTopTracksCard(
        tracks: stats.topTracks,
        actingKey: actingKey,
        onPlay: ref.read(statsViewModelProvider.notifier).play,
      ),
      const SizedBox(height: 12),
      StatBarsCard(
        title: '常听专辑 Top 8',
        rows: <({String name, int value})>[
          for (final a in stats.topAlbums) (name: a.album, value: a.playCount),
        ],
      ),
    ];
  }
}
