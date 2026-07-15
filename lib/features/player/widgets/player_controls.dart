import 'package:flutter/material.dart';

import '../../../core/audio/models/hmusic_playback_state.dart' show PlayMode;
import 'player_mode_button.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({
    required this.isPlaying,
    required this.isBusy,
    required this.mode,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onModeChanged,
    required this.favorite,
    super.key,
  });

  final bool isPlaying;
  final bool isBusy;
  final PlayMode mode;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<PlayMode> onModeChanged;

  // 行尾插槽：喜欢按钮，与行首模式按钮对称（spaceBetween 五等分）。
  final Widget favorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        PlayerModeButton(mode: mode, onChanged: onModeChanged),
        IconButton(
          iconSize: 40,
          tooltip: '上一首',
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: isBusy ? null : onPrevious,
        ),
        _PlayPauseButton(
          isPlaying: isPlaying,
          isBusy: isBusy,
          onPressed: onPlayPause,
        ),
        IconButton(
          iconSize: 40,
          tooltip: '下一首',
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: isBusy ? null : onNext,
        ),
        favorite,
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 72,
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isBusy ? null : onPressed,
          child: Center(
            child: isBusy
                ? SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.onPrimary,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 40,
                    color: scheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
