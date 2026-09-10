import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../view_models/player_view_model.dart';
import 'desktop_track_info.dart';
import 'player_favorite_button.dart';
import 'player_mode_button.dart';
import 'player_output_button.dart';
import 'player_queue_button.dart';
import 'player_seek_bar.dart';
import 'player_target_volume.dart';
import 'player_transport_controls.dart';

class DesktopWidePlayback extends ConsumerWidget {
  const DesktopWidePlayback({required this.state, super.key});
  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = SizedBox.square(
      dimension: 44,
      child: PlayerModeButton(
        mode: state.playMode,
        onChanged: ref.read(playerViewModelProvider).setPlayMode,
      ),
    );
    final transport = PlayerTransportControls(
      state: state,
      compact: true,
      showSecondaryControls: false,
    );
    final favorite = SizedBox.square(
      dimension: 44,
      child: PlayerFavoriteButton(track: state.track),
    );
    final queue = PlayerQueueButton(length: state.queueLength);
    final output = PlayerOutputButton(state: state, showLabel: true);
    final progress = PlayerSeekBar(state: state, inlineTimes: true);
    final volume = PlayerTargetVolume(state: state);
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Row(
            children: <Widget>[
              Expanded(child: DesktopTrackInfo(state: state)),
              favorite,
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[mode, transport],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(height: 44, child: progress),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 44,
                child: Row(
                  children: <Widget>[
                    Expanded(child: output),
                    queue,
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(height: 44, child: volume),
            ],
          ),
        ),
      ],
    );
  }
}
