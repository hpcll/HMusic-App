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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = widget.duration.inMilliseconds.toDouble();
    final hasDuration = maxMs > 0;
    final liveMs = widget.position.inMilliseconds
        .clamp(0, hasDuration ? maxMs.toInt() : 0)
        .toDouble();
    final value = _dragValue ?? liveMs;

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
                    setState(() => _dragValue = null);
                    widget.onSeek(Duration(milliseconds: v.round()));
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
