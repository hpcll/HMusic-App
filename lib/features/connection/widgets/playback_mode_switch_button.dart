import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_switch.dart';

class PlaybackModeSwitchButton extends ConsumerWidget {
  const PlaybackModeSwitchButton({
    required this.mode,
    required this.path,
    required this.label,
    this.showError = true,
    super.key,
  });

  final PlaybackMode mode;
  final String path;
  final String label;
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackModeSwitchProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: state.busy
              ? null
              : () async {
                  final ok = await ref
                      .read(playbackModeSwitchProvider.notifier)
                      .select(mode);
                  if (ok && context.mounted) context.go(path);
                },
          icon: Icon(switch (mode) {
            PlaybackMode.direct => Icons.speaker_group_outlined,
            PlaybackMode.server => Icons.lan_outlined,
            PlaybackMode.player => Icons.headphones_outlined,
          }),
          label: Text(state.busy ? '正在切换…' : label),
        ),
        if (showError && state.error != null)
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
