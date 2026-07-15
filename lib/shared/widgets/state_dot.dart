import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../../core/audio/models/hmusic_playback_state.dart';

// 播放状态点，对齐 web .dot：7px 圆。
// playing=accent（青绿，唯一表达「正在发生的事」）/ paused=#c99700 / idle·stopped=muted / error=danger。
class StateDot extends StatelessWidget {
  const StateDot(this.status, {this.size = 7, super.key});

  final PlaybackStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (status) {
      PlaybackStatus.playing => palette.accent,
      PlaybackStatus.paused => const Color(0xFFC99700),
      PlaybackStatus.error => palette.danger,
      _ => palette.muted,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
