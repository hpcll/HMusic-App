import 'package:flutter/material.dart';

import '../../../core/platform/client_playback_capabilities.dart';
import '../view_models/player_view_model.dart';

// 收起时下一首逐渐让位，播放键始终保持 44×44 的触达区域。
class MiniPlayerControls extends StatelessWidget {
  const MiniPlayerControls({
    required this.controller,
    required this.playing,
    required this.busy,
    required this.enabled,
    required this.hasTrack,
    required this.compactProgress,
    super.key,
  });

  final PlayerViewModel controller;
  final bool playing;
  final bool busy;
  final bool enabled;
  final bool hasTrack;
  final double compactProgress;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox.square(
        dimension: 44,
        child: IconButton(
          tooltip: hasTrack && !enabled
              ? ClientPlaybackCapabilities.localPlaybackUnavailableReason
              : playing
              ? '暂停'
              : '播放',
          iconSize: 26,
          onPressed: !enabled || busy
              ? null
              : playing
              ? controller.pause
              : controller.play,
          icon: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
      ),
      if (compactProgress < 1)
        ClipRect(
          child: Align(
            widthFactor: 1 - compactProgress,
            child: IgnorePointer(
              ignoring: compactProgress > 0.5,
              child: ExcludeSemantics(
                excluding: compactProgress > 0.5,
                child: Opacity(
                  opacity: 1 - compactProgress,
                  child: SizedBox.square(
                    dimension: 44,
                    child: IconButton(
                      tooltip: '下一首',
                      icon: const Icon(Icons.skip_next_rounded, size: 22),
                      onPressed: !enabled || busy
                          ? null
                          : controller.skipToNext,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
