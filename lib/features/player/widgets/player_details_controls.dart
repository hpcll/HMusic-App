import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/hmusic_inline_notice.dart';
import '../view_models/favorites_view_model.dart';
import 'lyric_strip.dart';
import 'player_device_status.dart';
import 'player_output_button.dart';
import 'player_seek_bar.dart';
import 'player_target_volume.dart';
import 'player_transport_controls.dart';

class PlayerDetailsControls extends ConsumerWidget {
  const PlayerDetailsControls({
    required this.state,
    required this.showLyricStrip,
    this.compact = false,
    super.key,
  });

  final HMusicPlaybackState state;
  final bool showLyricStrip;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.track!;
    final theme = Theme.of(context);
    final favoriteError = ref.watch(
      favoritesViewModelProvider.select((s) => s.error),
    );
    final supported = ref
        .watch(clientPlaybackCapabilitiesProvider)
        .canControl(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          track.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          !showLyricStrip && track.album?.isNotEmpty == true
              ? '${track.artist} · ${track.album}'
              : track.artist,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!state.isLocalDevice || !showLyricStrip) ...<Widget>[
          const SizedBox(height: 6),
          Center(child: PlayerDeviceStatus(state: state)),
        ],
        if (!supported) ...<Widget>[
          const SizedBox(height: 8),
          const HMusicInlineNotice(
            HMusicNotice(
              ClientPlaybackCapabilities.localPlaybackUnavailableReason,
            ),
          ),
        ],
        if (showLyricStrip) ...<Widget>[
          const SizedBox(height: 12),
          LyricStrip(durationMs: state.durationMs),
        ],
        const SizedBox(height: 12),
        PlayerSeekBar(state: state),
        const SizedBox(height: 8),
        PlayerTransportControls(state: state, compact: compact),
        if (favoriteError != null) ...<Widget>[
          const SizedBox(height: 8),
          HMusicInlineNotice(HMusicNotice.error(favoriteError)),
        ],
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(child: PlayerTargetVolume(state: state)),
            PlayerOutputButton(state: state),
          ],
        ),
      ],
    );
  }
}
