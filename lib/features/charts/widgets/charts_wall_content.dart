import 'package:flutter/material.dart';

import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/hmusic_inline_notice.dart';
import '../models/charts_view_state.dart';
import '../view_models/charts_view_model.dart';
import 'chart_home_editor.dart';
import 'charts_section_row.dart';
import 'charts_source_filter.dart';

// 首页精选按本机偏好混排；平台分类仍保留完整目录与个人常听入口。
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
          onManage: () => showChartHomeEditor(context, state.charts),
        ),
        if (state.selectedSource == 'featured' && state.discovery.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => showChartHomeEditor(context, state.charts),
              child: const Text('首页推荐已关闭，点此管理或切换平台查看榜单'),
            ),
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
