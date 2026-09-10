import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/brand_mark.dart';
import '../theme/hmusic_palette.dart';
import 'navigation_destinations.dart';
import 'sidebar_item.dart';

class SidebarBrandHeader extends StatelessWidget {
  const SidebarBrandHeader({required this.rail, super.key});

  final bool rail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(rail ? 0 : 10, 0, rail ? 0 : 10, 20),
    child: Row(
      mainAxisAlignment: rail
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: <Widget>[
        const BrandMark(size: 24),
        if (!rail) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'HMusic',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NotoSerifSC',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.palette.textStrong,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({required this.shell, required this.rail, super.key});

  final StatefulNavigationShell shell;
  final bool rail;

  @override
  Widget build(BuildContext context) => ListView(
    primary: false,
    padding: EdgeInsets.zero,
    children: <Widget>[
      for (final (label, destinations) in kSidebarGroups) ...<Widget>[
        _groupHeader(context, label),
        for (final spec in destinations)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SidebarItem(
              spec: spec,
              active: shell.currentIndex == spec.branch,
              rail: rail,
              onTap: () => shell.goBranch(
                spec.branch,
                initialLocation: spec.branch == shell.currentIndex,
              ),
            ),
          ),
      ],
    ],
  );

  Widget _groupHeader(BuildContext context, String label) {
    if (rail) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Divider(height: 1, color: context.palette.line),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 0, 5),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: context.palette.muted),
      ),
    );
  }
}
