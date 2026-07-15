import 'package:flutter/material.dart';

import '../../../core/audio/models/hmusic_playback_state.dart' show PlayMode;

class QueueModeTabs extends StatelessWidget {
  const QueueModeTabs({
    required this.active,
    required this.onSelect,
    super.key,
  });

  final PlayMode active;
  final ValueChanged<PlayMode> onSelect;

  static const List<(PlayMode, String)> _modes = <(PlayMode, String)>[
    (PlayMode.listLoop, '列表循环'),
    (PlayMode.singleLoop, '单曲循环'),
    (PlayMode.shuffle, '随机'),
    (PlayMode.sequence, '顺序'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final (mode, label) in _modes)
          ChoiceChip(
            label: Text(label),
            selected: active == mode,
            onSelected: (_) => onSelect(mode),
          ),
      ],
    );
  }
}
