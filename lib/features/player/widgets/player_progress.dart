import 'package:flutter/material.dart';

import 'duration_format.dart';

class PlayerProgress extends StatefulWidget {
  const PlayerProgress({
    required this.position,
    required this.duration,
    required this.seekEnabled,
    required this.onSeek,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final bool seekEnabled;
  final ValueChanged<Duration> onSeek;

  @override
  State<PlayerProgress> createState() => _PlayerProgressState();
}

class _PlayerProgressState extends State<PlayerProgress> {
  double? _dragValue;

  // 松手后的目标位置：seek 是异步的（服务端/播放器回读有延迟），松手瞬间
  // 若直接回落到旧的 live position，拇指会先弹回再跳到目标。hold 住目标值
  // 直到外部 position 追上（2s 容差内）或曲目切换（duration 变化）。
  Duration? _pendingSeek;

  @override
  void didUpdateWidget(PlayerProgress old) {
    super.didUpdateWidget(old);
    final pending = _pendingSeek;
    if (pending == null) return;
    if (old.duration != widget.duration ||
        (widget.position - pending).abs() < const Duration(seconds: 2)) {
      _pendingSeek = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = widget.duration.inMilliseconds.toDouble();
    final hasDuration = maxMs > 0;
    final pendingMs = _pendingSeek?.inMilliseconds.toDouble();
    final liveMs = widget.position.inMilliseconds
        .clamp(0, hasDuration ? maxMs.toInt() : 0)
        .toDouble();
    final value = (_dragValue ?? pendingMs ?? liveMs)
        .clamp(0.0, hasDuration ? maxMs : 0.0)
        .toDouble();

    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: hasDuration ? value : 0,
            max: hasDuration ? maxMs : 1,
            onChanged: hasDuration && widget.seekEnabled
                ? (v) => setState(() => _dragValue = v)
                : null,
            onChangeEnd: hasDuration && widget.seekEnabled
                ? (v) {
                    final target = Duration(milliseconds: v.round());
                    setState(() {
                      _dragValue = null;
                      _pendingSeek = target;
                    });
                    widget.onSeek(target);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                formatDuration(Duration(milliseconds: value.round())),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                formatDuration(widget.duration),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
