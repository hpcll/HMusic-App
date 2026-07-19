import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../view_models/lyric_view_model.dart';
import '../view_models/player_view_model.dart';
import '../widgets/lyric_scroll_view.dart';
import '../widgets/lyrics_mini_controls.dart';

// 沉浸歌词页（/lyrics，窄屏专用）：头部收起键 + 曲名/歌手 → 全屏歌词滚动 → 迷你播控。
// 真路由，系统返回手势天然可退出。当前行按 just_audio 实时进度算（本机播放真相源），
// 歌词缓存与播放页共享（同曲不重复请求）。对齐 docs/04 屏 2b。
class LyricsPage extends ConsumerWidget {
  const LyricsPage({super.key});

  static const String path = '/lyrics';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverPlaybackStateProvider);
    return Scaffold(
      body: SafeArea(
        child: serverState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('播放状态不可用：$error')),
          data: (state) => _LyricsBody(state: state),
        ),
      ),
    );
  }
}

class _LyricsBody extends ConsumerWidget {
  const _LyricsBody({required this.state});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final track = state.track;
    final controller = ref.read(playerViewModelProvider);

    // 进度真相源经 playbackPositionOf 分流（本机 just_audio / 远端服务端回读）。
    final positionMs = playbackPositionOf(ref, state).inMilliseconds;
    final activeLine = ref
        .read(lyricViewModelProvider.notifier)
        .activeLineFor(positionMs);

    return Column(
      children: <Widget>[
        _Head(
          title: track?.title ?? '歌词',
          artist: track?.artist ?? '',
          palette: palette,
        ),
        Expanded(
          child: LyricScrollView(
            activeLine: activeLine,
            seekEnabled: state.seekEnabled,
            onLineTap: (timeMs) =>
                controller.seek(Duration(milliseconds: timeMs)),
          ),
        ),
        LyricsMiniControls(state: state, controller: controller),
      ],
    );
  }
}

// 头部：收起键 + 居中曲名/歌手（右侧等宽 spacer 保证绝对居中）。
class _Head extends StatelessWidget {
  const _Head({
    required this.title,
    required this.artist,
    required this.palette,
  });

  final String title;
  final String artist;
  final HMusicPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '收起歌词',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: palette.muted),
                  ),
              ],
            ),
          ),
          // 与左侧收起键等宽，保证标题绝对居中。
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
