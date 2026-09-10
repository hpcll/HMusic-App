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
    this.compact = false,
    this.enabled = true,
    this.showMode = true,
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
  final Widget? favorite;
  final bool compact;
  final bool enabled;
  final bool showMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: <Widget>[
        if (showMode) PlayerModeButton(mode: mode, onChanged: onModeChanged),
        IconButton(
          iconSize: compact ? 26 : 40,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          tooltip: '上一首',
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: isBusy || !enabled ? null : onPrevious,
        ),
        _PlayPauseButton(
          isPlaying: isPlaying,
          isBusy: isBusy,
          compact: compact,
          enabled: enabled,
          onPressed: onPlayPause,
        ),
        IconButton(
          iconSize: compact ? 26 : 40,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          tooltip: '下一首',
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: isBusy || !enabled ? null : onNext,
        ),
        if (favorite != null) favorite!,
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBusy,
    required this.onPressed,
    required this.compact,
    required this.enabled,
  });

  final bool isPlaying;
  final bool isBusy;
  final VoidCallback onPressed;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled && !isBusy,
      label: isBusy
          ? '正在加载'
          : isPlaying
          ? '暂停'
          : '播放',
      child: Tooltip(
        message: isBusy
            ? '正在加载'
            : isPlaying
            ? '暂停'
            : '播放',
        child: SizedBox.square(
          dimension: compact ? 44 : 72,
          child: Material(
            color: enabled
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: .2),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isBusy || !enabled ? null : onPressed,
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
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: compact ? 28 : 40,
                        color: scheme.onPrimary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
