import 'package:flutter/material.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../models/mi_account_state.dart';

// 通道切换条，对齐 web .tabs：panel-2 底 + 3px 内衬，激活项 panel 底 + text-strong 字 + 细阴影。
class MiTabs extends StatelessWidget {
  const MiTabs({required this.active, required this.onSelect, super.key});

  final MiTab active;
  final ValueChanged<MiTab> onSelect;

  static const List<(MiTab, String)> _tabs = <(MiTab, String)>[
    (MiTab.qr, '扫码登录'),
    (MiTab.password, '账号密码'),
    (MiTab.importSession, '导入会话'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.panelSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: <Widget>[
          for (final (tab, label) in _tabs)
            Expanded(child: _tab(palette, tab, label)),
        ],
      ),
    );
  }

  Widget _tab(HMusicPalette palette, MiTab tab, String label) {
    final isActive = tab == active;
    return Material(
      color: isActive ? palette.panel : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => onSelect(tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              color: isActive ? palette.textStrong : palette.mutedStrong,
            ),
          ),
        ),
      ),
    );
  }
}
