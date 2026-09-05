import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../models/hmusic_notice.dart';

// Apple 式就地反馈行：反馈出现在它发生的上下文里（表单下方、列表页头），
// 不再悬浮遮挡——成功 ✓ 青绿 / 错误 ⚠ 红 / info 无图标灰字。
// 各页直接渲染 state.notice；生命周期归 VM：下次动作会覆盖或清除。
class HMusicInlineNotice extends StatelessWidget {
  const HMusicInlineNotice(this.notice, {super.key});

  final HMusicNotice notice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isError = notice.kind == HMusicNoticeKind.error;
    final color = isError ? palette.danger : palette.mutedStrong;
    return Row(
      children: <Widget>[
        if (notice.kind == HMusicNoticeKind.success) ...<Widget>[
          Icon(Icons.check_rounded, size: 15, color: palette.accent),
          const SizedBox(width: 7),
        ] else if (isError) ...<Widget>[
          Icon(Icons.error_outline_rounded, size: 15, color: palette.danger),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(
            notice.message,
            style: TextStyle(fontSize: 13, height: 1.35, color: color),
          ),
        ),
      ],
    );
  }
}
