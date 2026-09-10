import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/layout/shell_metrics.dart';
import '../theme/hmusic_palette.dart';
import 'bottom_nav_item.dart';
import 'navigation_destinations.dart';

class BottomNavRow extends StatelessWidget {
  const BottomNavRow({
    required this.shell,
    this.badgedBranch,
    this.hideSelectedIcon = false,
    super.key,
  });

  final StatefulNavigationShell shell;
  final int? badgedBranch;
  final bool hideSelectedIcon;

  @override
  Widget build(BuildContext context) {
    final branch = mobileParentBranch(shell.currentIndex);
    final activeIndex = kNavDestinations.indexWhere(
      (item) => item.branch == branch,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        if (activeIndex >= 0)
          AnimatedAlign(
            alignment: Alignment(
              -1 + activeIndex * 2 / (kNavDestinations.length - 1),
              0,
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : kDockPillDuration,
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / kNavDestinations.length,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: context.palette.textStrong.withValues(
                      alpha: dark ? 0.12 : 0.07,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),
        Row(
          children: <Widget>[
            for (final spec in kNavDestinations)
              Expanded(
                child: BottomNavItem(
                  spec: spec,
                  active: branch == spec.branch,
                  showIcon: !hideSelectedIcon || branch != spec.branch,
                  badged: badgedBranch == spec.branch,
                  onTap: () => shell.goBranch(
                    spec.branch,
                    initialLocation: spec.branch == shell.currentIndex,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
