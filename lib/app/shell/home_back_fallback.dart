import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../shared/layout/shell_metrics.dart';
import 'navigation_destinations.dart';

// 分支内详情先处理返回，壳层将统计回到曲库，再由主要入口回找歌。
class HomeBackFallback extends StatelessWidget {
  const HomeBackFallback({required this.shell, required this.child, super.key});

  final StatefulNavigationShell shell;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: shell.currentIndex == kHomeBranch,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final fromStats =
            shell.currentIndex == kStatsBranch &&
            usesBottomNavigation(MediaQuery.sizeOf(context).width);
        shell.goBranch(fromStats ? kLibraryBranch : kHomeBranch);
      },
      child: child,
    );
  }
}
