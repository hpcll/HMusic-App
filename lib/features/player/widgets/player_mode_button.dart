import 'package:flutter/material.dart';

import '../../../core/audio/models/hmusic_playback_state.dart' show PlayMode;

// 播放模式循环切换：列表循环 → 单曲循环 → 随机 → 顺序 → …
class PlayerModeButton extends StatelessWidget {
  const PlayerModeButton({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final PlayMode mode;
  final ValueChanged<PlayMode> onChanged;

  static const List<PlayMode> _cycle = <PlayMode>[
    PlayMode.listLoop,
    PlayMode.singleLoop,
    PlayMode.shuffle,
    PlayMode.sequence,
  ];

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _describe(mode);
    return IconButton(
      tooltip: label,
      icon: Icon(icon),
      onPressed: () {
        final index = _cycle.indexOf(mode);
        final next = _cycle[(index + 1) % _cycle.length];
        onChanged(next);
      },
    );
  }

  (IconData, String) _describe(PlayMode mode) {
    return switch (mode) {
      PlayMode.singleLoop => (Icons.repeat_one_rounded, '单曲循环'),
      PlayMode.shuffle => (Icons.shuffle_rounded, '随机'),
      PlayMode.sequence => (Icons.playlist_play_rounded, '顺序'),
      PlayMode.singleOnce => (Icons.looks_one_rounded, '单次'),
      PlayMode.listLoop || PlayMode.unknown => (Icons.repeat_rounded, '列表循环'),
    };
  }
}
