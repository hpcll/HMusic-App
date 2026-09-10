import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../view_models/player_view_model.dart';
import 'player_controls.dart';
import 'player_favorite_button.dart';

// 复用 handler 播控投影，布局只选择尺寸与次要控制的位置。
class PlayerTransportControls extends ConsumerWidget {
  const PlayerTransportControls({
    required this.state,
    this.compact = false,
    this.showSecondaryControls = true,
    super.key,
  });

  final HMusicPlaybackState state;
  final bool compact;
  final bool showSecondaryControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackControlsStateProvider);
    final value = playback.value;
    final controller = ref.read(playerViewModelProvider);
    final enabled =
        (state.track != null || state.queueLength > 0) &&
        ref.watch(clientPlaybackCapabilitiesProvider).canControl(state) &&
        !playback.hasError;
    final playing = value?.playing ?? false;
    final busy =
        playback.isLoading ||
        value?.processingState == AudioProcessingState.loading ||
        value?.processingState == AudioProcessingState.buffering;
    return PlayerControls(
      isPlaying: playing,
      isBusy: busy,
      enabled: enabled,
      compact: compact,
      showMode: showSecondaryControls,
      mode: state.playMode,
      onPlayPause: playing ? controller.pause : controller.play,
      onPrevious: controller.skipToPrevious,
      onNext: controller.skipToNext,
      onModeChanged: controller.setPlayMode,
      favorite: showSecondaryControls
          ? PlayerFavoriteButton(track: state.track)
          : null,
    );
  }
}
