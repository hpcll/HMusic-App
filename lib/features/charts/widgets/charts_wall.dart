import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/charts_view_state.dart';
import '../view_models/charts_view_model.dart';
import 'charts_header.dart';
import 'charts_wall_content.dart';

// 找歌/榜单根内容：手机保留吸顶搜索，常听与发现按实际内容宽度布局。
class ChartsWall extends ConsumerWidget {
  const ChartsWall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chartsViewModelProvider);
    final notifier = ref.read(chartsViewModelProvider.notifier);
    if (state.status == ChartsStatus.loading && state.charts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == ChartsStatus.error && state.charts.isEmpty) {
      return _ChartsWallError(message: state.errorMessage ?? '榜单加载失败');
    }
    final mobile = usesBottomNavigation(MediaQuery.sizeOf(context).width);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: CustomScrollView(
          key: const PageStorageKey<String>('charts-wall'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            if (mobile)
              SliverPersistentHeader(
                pinned: true,
                delegate: ChartsHeaderDelegate(
                  topPadding: MediaQuery.paddingOf(context).top,
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              )
            else
              SliverToBoxAdapter(
                child: _DesktopChartsTitle(
                  onRefresh: state.status == ChartsStatus.loading
                      ? null
                      : notifier.load,
                ),
              ),
            SliverToBoxAdapter(
              child: ChartsWallContent(state: state, notifier: notifier),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopChartsTitle extends StatelessWidget {
  const _DesktopChartsTitle({this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        24 + MediaQuery.paddingOf(context).top,
        16,
        20,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ViewTitle('榜单'),
                const SizedBox(height: 6),
                Text(
                  '常听回顾，热门发现',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.palette.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: '刷新榜单',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChartsWallError extends StatelessWidget {
  const _ChartsWallError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Text(
                '$message（下拉重试）',
                style: TextStyle(color: context.palette.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
