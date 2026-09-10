import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import 'hmusic_icon_button.dart';

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
    return Semantics(
      value: confirmed ? '已完成' : (_acting ? '处理中' : null),
      child: HMusicIconButton(
        icon: confirmed ? Icons.check_rounded : widget.icon,
        tooltip: widget.tooltip,
        onPressed: _acting || confirmed ? null : () => unawaited(_tap()),
        foregroundColor: confirmed ? palette.accent : null,
        dimWhenDisabled: !confirmed,
      ),
    );
  }
}
