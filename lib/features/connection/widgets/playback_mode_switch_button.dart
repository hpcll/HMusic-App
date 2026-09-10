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
    super.key,
  });

  final PlaybackMode mode;
  final String path;
  final String label;

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
          icon: Icon(
            mode == PlaybackMode.direct
                ? Icons.speaker_group_outlined
                : Icons.lan_outlined,
          ),
          label: Text(state.busy ? '正在切换…' : label),
        ),
        if (state.error != null)
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
