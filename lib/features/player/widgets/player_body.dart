import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../view_models/lyric_view_model.dart';
import '../view_models/player_view_model.dart';
import 'lyric_scroll_view.dart';
import 'player_stage.dart';

// 形态取内容区真实宽高；侧栏宽度、标题栏和安全区已经由外壳扣除。
class PlayerBody extends ConsumerWidget {
  const PlayerBody({required this.state, super.key});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.track;
    if (track == null) {
      return const Center(child: Text('还没有在播放的歌曲'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final scaledTitle = MediaQuery.textScalerOf(context).scale(14);
        final wide = width >= 860 && height >= 500 && scaledTitle <= 21;
        if (!wide) {
          return PlayerStage(
            state: state,
            horizontal: width >= 600 && height < 500,
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 11,
                  child: PlayerStage(state: state, showLyricStrip: false),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: _PlayerLyrics(state: state),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerLyrics extends ConsumerWidget {
  const _PlayerLyrics({required this.state});
  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = playbackPositionOf(ref, state).inMilliseconds;
    return LyricScrollView(
      activeLine: ref.watch(lyricViewModelProvider).activeLineFor(position),
      seekEnabled:
          state.seekEnabled &&
          ref.watch(clientPlaybackCapabilitiesProvider).canControl(state),
      onLineTap: (timeMs) => ref
          .read(playerViewModelProvider)
          .seek(Duration(milliseconds: timeMs)),
    );
  }
}
