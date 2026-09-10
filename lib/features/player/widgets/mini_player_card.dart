import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../view_models/player_view_model.dart';
import '../views/player_page.dart';
import 'mini_player_controls.dart';
import 'mini_player_track_info.dart';

// 保留纤细玻璃胶囊和原有播控；设备选择仍在完整播放器里。
class MiniPlayerCard extends StatelessWidget {
  const MiniPlayerCard({
    required this.state,
    required this.playbackState,
    required this.enabled,
    required this.controller,
    this.compactProgress = 0,
    super.key,
  });

  final HMusicPlaybackState? state;
  final PlaybackState? playbackState;
  final bool enabled;
  final PlayerViewModel controller;
  final double compactProgress;

  @override
  Widget build(BuildContext context) {
    final track = state?.track;
    final playing = playbackState?.playing ?? false;
    final busy =
        track != null &&
        (playbackState == null ||
            playbackState?.processingState == AudioProcessingState.loading ||
            playbackState?.processingState == AudioProcessingState.buffering);
    final height = mobileMiniPlayerHeight(MediaQuery.textScalerOf(context));
    final radius = BorderRadius.circular(height / 2);
    final VoidCallback? openPlayer = track == null
        ? null
        : () => _openPlayer(context);
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.zero,
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openPlayer,
          excludeFromSemantics: true,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  HMusicCover(
                    url: track?.coverUrl,
                    size: 32,
                    radius: 7,
                    iconSize: 13,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MiniPlayerTrackInfo(
                      state: state,
                      onOpenPlayer: openPlayer,
                      compactProgress: compactProgress,
                    ),
                  ),
                  MiniPlayerControls(
                    controller: controller,
                    playing: playing,
                    busy: busy,
                    enabled: enabled,
                    hasTrack: track != null,
                    compactProgress: compactProgress,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    if (usesBottomNavigation(MediaQuery.sizeOf(context).width)) {
      unawaited(context.push(PlayerPage.path));
    } else {
      context.go(PlayerPage.tabPath);
    }
  }
}
