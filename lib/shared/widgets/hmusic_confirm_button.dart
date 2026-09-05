import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/hmusic_palette.dart';

// 行内操作的「原地确认」按钮：视觉与 HMusicIconButton 同一语言（34 圆 / line 边）。
// onAction 返回 true（成功）→ 图标原地转青绿 ✓ 驻留 1.6s 再回弹——Apple Music
// 「已添加」同款反馈，替代浮层 toast；失败保持原样（错误由页面内联展示）。
// 进行中防重入；「减弱动态效果」时 ✓ 直切直回。
class HMusicConfirmButton extends StatefulWidget {
  const HMusicConfirmButton({
    required this.icon,
    required this.tooltip,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String tooltip;

  // 返回 true = 操作成功，显示 ✓；false / 抛异常 = 失败，原样。
  final Future<bool> Function() onAction;

  @override
  State<HMusicConfirmButton> createState() => _HMusicConfirmButtonState();
}

class _HMusicConfirmButtonState extends State<HMusicConfirmButton> {
  static const Duration _holdDuration = Duration(milliseconds: 1600);

  bool _acting = false;
  bool _confirmed = false;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_acting || _confirmed) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _acting = true);
    bool ok;
    try {
      ok = await widget.onAction();
    } on Exception {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _acting = false);
    if (!ok) return;
    setState(() => _confirmed = true);
    _revertTimer?.cancel();
    _revertTimer = Timer(_holdDuration, () {
      if (mounted) setState(() => _confirmed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final confirmed = _confirmed;
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: palette.panel,
        shape: CircleBorder(side: BorderSide(color: palette.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _acting || confirmed ? null : _tap,
          child: Opacity(
            opacity: _acting ? 0.5 : 1,
            child: Icon(
              confirmed ? Icons.check_rounded : widget.icon,
              size: 16,
              color: confirmed ? palette.accent : palette.textStrong,
            ),
          ),
        ),
      ),
    );
  }
}
