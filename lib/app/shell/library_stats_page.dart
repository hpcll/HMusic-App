import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/stats/views/stats_page.dart';
import '../../shared/layout/shell_metrics.dart';
import '../../shared/widgets/back_link.dart';

// 手机统计属于曲库，保留原统计页面和 /stats 路由，仅补回父入口的可见控制。
class LibraryStatsPage extends StatelessWidget {
  const LibraryStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!usesBottomNavigation(MediaQuery.sizeOf(context).width)) {
      return const StatsPage();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BackLink(
                label: '曲库',
                onTap: () => context.go('/playlists'),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: const StatsPage(),
          ),
        ),
      ],
    );
  }
}
