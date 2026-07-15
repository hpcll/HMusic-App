import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';

// 圆形图标按钮原子，对齐 web .icon-btn：34×34 圆 / line 边 / hover 边→strong / svg 16px。
// ghost 变体：无边透明底、muted-2 字（对齐 .icon-btn.ghost）。
class HMusicIconButton extends StatelessWidget {
  const HMusicIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.ghost = false,
    this.size = 34,
    this.iconSize = 16,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool ghost;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: ghost ? Colors.transparent : palette.panel,
        shape: CircleBorder(
          side: BorderSide(color: ghost ? Colors.transparent : palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Icon(
              icon,
              size: iconSize,
              color: ghost ? palette.mutedStrong : palette.textStrong,
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
