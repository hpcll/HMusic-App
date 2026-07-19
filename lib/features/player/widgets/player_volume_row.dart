import 'dart:async';

import 'package:flutter/material.dart';

// 播放目标音量条。两种提交模式由调用方决定：
// - 本机（just_audio 0-1）：onChanged 连续生效并持久化本地偏好；
// - 远端音箱（Server 0-100 映射到 0-1）：拖动只更新视觉，onChangeEnd 一次提交，
//   避免拖动期间设备指令刷屏。
// 非拖动时跟随外部 initialVolume（远端轮询回读的音箱真实音量）。
class PlayerVolumeRow extends StatefulWidget {
  const PlayerVolumeRow({
    required this.initialVolume,
    required this.onChanged,
    this.onChangeEnd,
    super.key,
  });

  final double initialVolume;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<PlayerVolumeRow> createState() => _PlayerVolumeRowState();
}

class _PlayerVolumeRowState extends State<PlayerVolumeRow> {
  late double _volume = widget.initialVolume.clamp(0, 1);
  bool _dragging = false;

  @override
  void didUpdateWidget(PlayerVolumeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.initialVolume != oldWidget.initialVolume) {
      _volume = widget.initialVolume.clamp(0, 1);
    }
  }

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
              onChangeStart: (_) => _dragging = true,
              onChanged: (value) {
                setState(() => _volume = value);
                unawaited(Future<void>.sync(() => widget.onChanged(value)));
              },
              onChangeEnd: (value) {
                _dragging = false;
                final commit = widget.onChangeEnd;
                if (commit != null) {
                  unawaited(Future<void>.sync(() => commit(value)));
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
