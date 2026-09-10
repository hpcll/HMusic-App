import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/client_playback_capabilities.dart';
import '../view_models/player_view_model.dart';
import 'desktop_playback_bar.dart';
import 'mini_player_card.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({this.capsule = false, this.compactProgress = 0, super.key});

  final bool capsule;
  final double compactProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!capsule) return const DesktopPlaybackBar();
    final state = ref.watch(serverPlaybackStateProvider).value;
    final playback = ref.watch(playbackControlsStateProvider);
    return MiniPlayerCard(
      state: state,
      playbackState: playback.value,
      enabled:
          state?.track != null &&
          !playback.hasError &&
          ref.watch(clientPlaybackCapabilitiesProvider).canControl(state!),
      controller: ref.read(playerViewModelProvider),
      compactProgress: compactProgress,
    );
  }
}
