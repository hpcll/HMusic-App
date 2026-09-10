import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/hmusic_palette.dart';

// 圆形图标按钮原子，对齐 web .icon-btn：34×34 圆 / line 边 / hover 边→strong / svg 16px。
// 视觉 34、命中区 44（44pt 触达标准，行内并排 2-3 个不再难点中）。
// ghost 变体：无边透明底、muted-2 字（对齐 .icon-btn.ghost）。
class HMusicIconButton extends StatefulWidget {
  const HMusicIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.ghost = false,
    this.size = 34,
    this.iconSize = 16,
    this.foregroundColor,
    this.dimWhenDisabled = true,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool ghost;
  final double size;
  final double iconSize;
  final Color? foregroundColor;
  final bool dimWhenDisabled;

  @override
  State<HMusicIconButton> createState() => _HMusicIconButtonState();
}

class _HMusicIconButtonState extends State<HMusicIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = widget.onPressed != null;
    final button = SizedBox.square(
      // 命中区 44：视觉圆只有 34，外圈透明但可点。
      dimension: widget.size < 44 ? 44 : widget.size,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled
              ? () {
                  unawaited(HapticFeedback.selectionClick());
                  widget.onPressed!();
                }
              : null,
          onHover: (hovering) => setState(() => _hover = hovering),
          child: Center(
            child: Ink(
              width: widget.size,
              height: widget.size,
              decoration: ShapeDecoration(
                color: widget.ghost ? Colors.transparent : palette.panel,
                shape: CircleBorder(
                  side: BorderSide(
                    color: widget.ghost
                        ? Colors.transparent
                        : _hover
                        ? palette.mutedStrong
                        : palette.line,
                  ),
                ),
              ),
              child: Opacity(
                opacity: enabled || !widget.dimWhenDisabled ? 1 : 0.5,
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color:
                      widget.foregroundColor ??
                      (widget.ghost ? palette.mutedStrong : palette.textStrong),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
