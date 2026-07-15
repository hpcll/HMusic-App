import 'dart:async';

import 'package:flutter/material.dart';

// 本机音量条：真相源是 just_audio 的 volume（0-1），拖动即时生效并持久化。
// 远程音箱音量走 Server，不在此控件范围（P1 设备切换时另做）。
class PlayerVolumeRow extends StatefulWidget {
  const PlayerVolumeRow({
    required this.initialVolume,
    required this.onChanged,
    super.key,
  });

  final double initialVolume;
  final ValueChanged<double> onChanged;

  @override
  State<PlayerVolumeRow> createState() => _PlayerVolumeRowState();
}

class _PlayerVolumeRowState extends State<PlayerVolumeRow> {
  late double _volume = widget.initialVolume.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(
          _volume <= 0.01
              ? Icons.volume_off_rounded
              : _volume < 0.5
              ? Icons.volume_down_rounded
              : Icons.volume_up_rounded,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: _volume,
              onChanged: (value) {
                setState(() => _volume = value);
                unawaited(Future<void>.sync(() => widget.onChanged(value)));
              },
            ),
          ),
        ),
      ],
    );
  }
}
