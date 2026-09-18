import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/back_link.dart';
import '../../../shared/widgets/hmusic_inline_notice.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/chart.dart';
import '../models/charts_view_state.dart';
import '../view_models/charts_view_model.dart';

class ChartDetailHeader extends StatelessWidget {
  const ChartDetailHeader({
    required this.state,
    required this.notifier,
    required this.chart,
    required this.hasEntries,
    super.key,
  });

  final ChartsViewState state;
  final ChartsViewModel notifier;
  final Chart chart;
  final bool hasEntries;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  // Apple 榜条目可由服务端匹配，只要有条目就允许整榜播放。
                  if (hasEntries)
                    OutlinedButton(
                      onPressed: state.actingRank == 0
                          ? notifier.playAll
                          : null,
                      child: const Text('播放全部'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ViewTitle(chart.name),
              if (chart.description?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  chart.description!,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.palette.muted,
                  ),
                ),
              ],
              if (state.errorMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                HMusicInlineNotice(HMusicNotice.error(state.errorMessage!)),
              ],
              if (state.detail?.notice case final notice?) ...[
                const SizedBox(height: 10),
                HMusicInlineNotice(HMusicNotice(notice)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _status(context),
      ],
    );
  }

  Widget _status(BuildContext context) {
    if (state.detailLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasEntries) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Center(
        child: Text(
          chart.id == 'family' ? '还没有播放记录，放几首歌就有家庭热播榜了' : '榜单是空的',
          style: TextStyle(color: context.palette.muted),
        ),
      ),
    );
  }
}
