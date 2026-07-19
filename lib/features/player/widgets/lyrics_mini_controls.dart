import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../view_models/player_view_model.dart';
import 'player_progress.dart';

// 沉浸歌词页底部迷你播控：进度条（可拖）+ 上一曲·播放暂停·下一曲三键。
// 进度真相源经 playbackPositionOf 分流（本机 just_audio / 远端服务端回读）。
class LyricsMiniControls extends ConsumerWidget {
  const LyricsMiniControls({
    required this.state,
    required this.controller,
    super.key,
  });

  final HMusicPlaybackState state;
  final PlayerViewModel controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = playbackPositionOf(ref, state);
    final handlerAsync = ref.watch(hmusicAudioHandlerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlayerProgress(
            position: position,
            duration: Duration(milliseconds: state.durationMs),
            seekEnabled: state.seekEnabled,
            onSeek: controller.seek,
          ),
          const SizedBox(height: 4),
          handlerAsync.when(
            loading: () => const SizedBox(height: 56),
            error: (_, __) => const SizedBox(height: 56),
            data: (handler) => StreamBuilder<PlaybackState>(
              stream: handler.playbackState,
              builder: (context, snapshot) {
                final pbState = snapshot.data;
                final isPlaying = pbState?.playing ?? handler.player.playing;
                final isBusy =
                    pbState?.processingState == AudioProcessingState.loading ||
                    pbState?.processingState == AudioProcessingState.buffering;
                return _Buttons(
                  isPlaying: isPlaying,
                  isBusy: isBusy,
                  controller: controller,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 三键：上一曲 · 播放暂停(主键) · 下一曲。
class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.isPlaying,
    required this.isBusy,
    required this.controller,
  });

  final bool isPlaying;
  final bool isBusy;
  final PlayerViewModel controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          iconSize: 38,
          tooltip: '上一首',
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: isBusy ? null : controller.skipToPrevious,
        ),
        const SizedBox(width: 24),
        SizedBox.square(
          dimension: 64,
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isBusy
                  ? null
                  : (isPlaying ? controller.pause : controller.play),
              child: Center(
                child: isBusy
                    ? SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 36,
                        color: scheme.onPrimary,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          iconSize: 38,
          tooltip: '下一首',
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: isBusy ? null : controller.skipToNext,
        ),
      ],
    );
  }
}
