import 'package:flutter/material.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../models/playback_output_label.dart';
import 'device_picker_sheet.dart';

class PlayerOutputButton extends StatelessWidget {
  const PlayerOutputButton({
    required this.state,
    this.showLabel = false,
    super.key,
  });

  final HMusicPlaybackState? state;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final label = playbackOutputLabel(state);
    final icon = Icon(
      state?.isLocalDevice ?? false
          ? Icons.devices_rounded
          : Icons.speaker_group_rounded,
      size: 20,
    );
    if (!showLabel) {
      return IconButton(
        tooltip: '播放设备：$label',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () => showDevicePickerSheet(context),
        icon: icon,
      );
    }
    return Tooltip(
      message: '播放设备：$label',
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () => showDevicePickerSheet(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
