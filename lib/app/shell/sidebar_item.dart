import 'package:flutter/material.dart';

import '../theme/hmusic_palette.dart';
import 'navigation_destinations.dart';

class SidebarItem extends StatefulWidget {
  const SidebarItem({
    required this.spec,
    required this.active,
    required this.onTap,
    this.rail = false,
    super.key,
  });

  final NavDestinationSpec spec;
  final bool active;
  final VoidCallback onTap;
  final bool rail;

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = widget.active ? palette.background : palette.mutedStrong;
    return Tooltip(
      message: widget.spec.label,
      excludeFromSemantics: true,
      child: Semantics(
        label: widget.spec.label,
        selected: widget.active,
        button: true,
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Material(
              color: widget.active
                  ? palette.textStrong
                  : _hover || _focused
                  ? palette.panelSecondary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                splashFactory: NoSplash.splashFactory,
                onTap: widget.onTap,
                onFocusChange: (value) => setState(() => _focused = value),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.rail ? 0 : 10,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisAlignment: widget.rail
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          widget.spec.icon,
                          size: widget.rail ? 23 : 18,
                          color: fg,
                        ),
                        if (!widget.rail) ...<Widget>[
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              widget.spec.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: fg),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
