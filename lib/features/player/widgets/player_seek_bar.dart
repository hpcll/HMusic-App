import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../view_models/player_view_model.dart';
import 'player_progress.dart';

class PlayerSeekBar extends ConsumerWidget {
  const PlayerSeekBar({
    required this.state,
    this.inlineTimes = false,
    super.key,
  });

  final HMusicPlaybackState state;
  final bool inlineTimes;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlayerProgress(
    // 换曲或切设备不能继承上一条尚未回读的拖动目标。
    key: ValueKey((state.track?.id, state.deviceId)),
    position: playbackPositionOf(ref, state),
    duration: Duration(milliseconds: state.durationMs),
    seekEnabled:
        state.seekEnabled &&
        ref.watch(clientPlaybackCapabilitiesProvider).canControl(state),
    onSeek: ref.read(playerViewModelProvider).seek,
    inlineTimes: inlineTimes,
  );
}
