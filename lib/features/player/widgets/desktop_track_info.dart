import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../models/playback_output_label.dart';
import '../view_models/favorites_view_model.dart';
import '../views/player_page.dart';

class DesktopTrackInfo extends ConsumerWidget {
  const DesktopTrackInfo({required this.state, super.key});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.track!;
    final supported = ref
        .watch(clientPlaybackCapabilitiesProvider)
        .canControl(state);
    final favoriteError = ref.watch(
      favoritesViewModelProvider.select((s) => s.error),
    );
    final String subtitle;
    if (!supported) {
      subtitle = ClientPlaybackCapabilities.localPlaybackUnavailableReason;
    } else if (favoriteError != null) {
      subtitle = favoriteError;
    } else if (state.state == PlaybackStatus.playing) {
      subtitle = track.artist;
    } else {
      subtitle = '${playbackStatusLabel(state)} · ${track.artist}';
    }
    return Tooltip(
      message: '${track.title}\n$subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go(PlayerPage.tabPath),
        child: Row(
          children: <Widget>[
            HMusicCover(url: track.coverUrl, size: 42, radius: 8, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color:
                          favoriteError != null ||
                              state.state == PlaybackStatus.error
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
