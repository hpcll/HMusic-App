import 'package:flutter/material.dart';

import '../theme/hmusic_palette.dart';
import 'navigation_destinations.dart';

const double kDockIconSize = 28;

class BottomNavItem extends StatelessWidget {
  const BottomNavItem({
    required this.spec,
    required this.active,
    required this.onTap,
    this.badged = false,
    this.compact = false,
    this.showIcon = true,
    super.key,
  });

  final NavDestinationSpec spec;
  final bool active;
  final VoidCallback onTap;
  final bool badged;
  final bool compact;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.palette.textStrong : context.palette.muted;
    final icon = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(spec.icon, size: kDockIconSize, color: color),
        if (badged)
          Positioned(
            right: 1,
            top: 3,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
    return Semantics(
      label: compact ? '展开导航，${spec.label}' : spec.label,
      button: true,
      selected: active,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.zero,
            child: compact
                ? Center(child: icon)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Opacity(opacity: showIcon ? 1 : 0, child: icon),
                      const SizedBox(height: 3),
                      Text(
                        spec.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: color,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
