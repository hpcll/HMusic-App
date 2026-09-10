import 'package:flutter/material.dart';

import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/hmusic_inline_notice.dart';
import '../models/charts_view_state.dart';
import '../view_models/charts_view_model.dart';
import 'charts_section_row.dart';
import 'charts_source_filter.dart';

// 个人常听与热门发现分层，精选只陈列各来源一个榜单，完整目录由筛选进入。
class ChartsWallContent extends StatelessWidget {
  const ChartsWallContent({
    required this.state,
    required this.notifier,
    super.key,
  });

  final ChartsViewState state;
  final ChartsViewModel notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 10),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: HMusicInlineNotice(HMusicNotice.error(state.errorMessage!)),
          ),
        if (state.personalCharts.isNotEmpty) ...<Widget>[
          ChartsSectionRow(
            label: '我的 Spotify 榜单',
            description: '来自 Spotify 的收听记录',
            charts: state.personalCharts,
            previews: state.previews,
            previewErrors: state.previewErrors,
            onRetry: notifier.retryPreview,
            onOpen: notifier.openChart,
            onPlayEntry: notifier.play,
          ),
          const SizedBox(height: 28),
        ],
        ChartsSourceFilter(
          charts: state.charts,
          selected: state.selectedSource,
          onSelected: notifier.selectSource,
        ),
        ChartsSectionRow(
          label: '',
          charts: state.discovery,
          previews: state.previews,
          previewErrors: state.previewErrors,
          onRetry: notifier.retryPreview,
          onOpen: notifier.openChart,
          onPlayEntry: notifier.play,
          horizontalOnMobile: false,
        ),
        SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}
