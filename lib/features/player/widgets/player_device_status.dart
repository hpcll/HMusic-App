import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../../shared/widgets/state_dot.dart';
import '../models/playback_output_label.dart';
import 'device_picker_sheet.dart';

class PlayerDeviceStatus extends ConsumerWidget {
  const PlayerDeviceStatus({required this.state, super.key});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text =
        '${playbackStatusLabel(state)} · ${playbackOutputLabel(state)}';
    return Tooltip(
      message: text,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: ref.watch(playbackModeProvider) == PlaybackMode.player
            ? null
            : () => showDevicePickerSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StateDot(state.state),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    color: context.palette.mutedStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
