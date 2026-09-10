import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../view_models/player_view_model.dart';
import 'desktop_playback_metrics.dart';
import 'desktop_track_info.dart';
import 'desktop_wide_playback.dart';
import 'player_favorite_button.dart';
import 'player_mode_button.dart';
import 'player_output_button.dart';
import 'player_queue_button.dart';
import 'player_seek_bar.dart';
import 'player_target_volume.dart';
import 'player_transport_controls.dart';

class DesktopPlaybackContent extends ConsumerWidget {
  const DesktopPlaybackContent({
    required this.state,
    required this.metrics,
    super.key,
  });

  final HMusicPlaybackState state;
  final DesktopPlaybackMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (metrics.layout == DesktopPlaybackLayout.wide) {
      return DesktopWidePlayback(state: state);
    }
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
    final stacked = metrics.layout == DesktopPlaybackLayout.stacked;
    return Column(
      children: <Widget>[
        SizedBox(
          height: metrics.metadataHeight,
          child: Row(
            children: <Widget>[
              Expanded(child: DesktopTrackInfo(state: state)),
              favorite,
              if (!stacked) ...<Widget>[
                const SizedBox(width: 12),
                SizedBox(width: 208, child: output),
              ],
              queue,
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: Row(
            children: <Widget>[
              mode,
              transport,
              const SizedBox(width: 16),
              Expanded(child: stacked ? output : progress),
              if (!stacked) ...<Widget>[
                const SizedBox(width: 16),
                SizedBox(width: 144, child: volume),
              ],
            ],
          ),
        ),
        if (stacked) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: Row(
              children: <Widget>[
                Expanded(child: progress),
                const SizedBox(width: 16),
                SizedBox(width: 144, child: volume),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
