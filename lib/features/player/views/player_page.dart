import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../shared/widgets/state_dot.dart';
import '../../queue/views/queue_page.dart';
import '../view_models/lyric_view_model.dart';
import '../view_models/player_view_model.dart';
import '../widgets/cover_swipe_area.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/lyric_scroll_view.dart';
import '../widgets/lyric_strip.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_cover.dart';
import '../widgets/player_favorite_button.dart';
import '../widgets/player_progress.dart';
import '../widgets/player_volume_row.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  // 双路由：/player 顶级 push（窄屏全屏覆盖，AppBar 带收起键）；
  // /now 为桌面 shell 分支 tab（外壳侧栏常驻，无 AppBar，不需要「退出」）。
  static const String path = '/player';
  static const String tabPath = '/now';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverPlaybackStateProvider);
    final controller = ref.read(playerViewModelProvider);
    // maybeOf 兜底：widget 测试直接挂 MaterialApp(home:) 时树里没有 GoRouter。
    final isTab =
        GoRouter.maybeOf(context) != null &&
        GoRouterState.of(context).matchedLocation == tabPath;

    final body = SafeArea(
      child: serverState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('播放状态不可用：$error')),
        data: (state) => _PlayerBody(state: state, controller: controller),
      ),
    );

    if (isTab) return body;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('正在播放'),
        actions: <Widget>[
          IconButton(
            tooltip: '播放队列',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () => context.push(QueuePage.path),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({required this.state, required this.controller});

  final HMusicPlaybackState state;
  final PlayerViewModel controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.track;
    if (track == null) {
      return const Center(child: Text('还没有在播放的歌曲'));
    }
    // track 变化拉歌词（VM 内按 source:sourceTrackId 去重，同曲不重复请求）。
    // build 内的 ref.listen 无 fireImmediately，首帧靠下方对当前 track 直接触发一次。
    ref.listen<HMusicTrack?>(
      serverPlaybackStateProvider.select((s) => s.value?.track),
      (_, next) => ref.read(lyricViewModelProvider.notifier).ensureLyric(next),
    );
    // 延到 build 之后触发，避免在 build 期间同步改 provider（riverpod 禁止）。
    unawaited(
      Future<void>.microtask(
        () => ref.read(lyricViewModelProvider.notifier).ensureLyric(track),
      ),
    );
    final handlerAsync = ref.watch(hmusicAudioHandlerProvider);
    final isPlaying = handlerAsync.maybeWhen(
      data: (handler) => _isPlayingStream(handler),
      orElse: () => false,
    );

    // 桌面双栏（≥1024，对齐 docs/04 屏 2 的 .np-grid）：左封面舞台 + 右歌词。
    // 窄屏单列（移动专属交互）：封面 → 曲名 → 染色歌词条 → 进度 → 主控。
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    return wide
        ? _WideBody(
            state: state,
            track: track,
            controller: controller,
            fallbackPlaying: isPlaying,
          )
        : _NarrowBody(
            state: state,
            track: track,
            controller: controller,
            fallbackPlaying: isPlaying,
          );
  }

  bool _isPlayingStream(HMusicAudioHandler handler) => handler.player.playing;
}

// 窄屏单列（对齐 docs/04 窄屏单屏模式）。
class _NarrowBody extends StatelessWidget {
  const _NarrowBody({
    required this.state,
    required this.track,
    required this.controller,
    required this.fallbackPlaying,
  });

  final HMusicPlaybackState state;
  final HMusicTrack track;
  final PlayerViewModel controller;
  final bool fallbackPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: <Widget>[
          // 封面占满剩余高度并保持正方形：矮屏/横屏自动收缩，不撑爆布局。
          // 移动专属：封面左右滑切歌（docs/05 手势表），桌面双栏不挂。
          Expanded(
            flex: 5,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: CoverSwipeArea(
                  onNext: controller.skipToNext,
                  onPrevious: controller.skipToPrevious,
                  child: PlayerCover(track: track),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            track.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // 遥控模式标识（仅目标为音箱时占行）：点击弹设备 sheet。
          if (!state.isLocalDevice) ...<Widget>[
            const SizedBox(height: 6),
            _DeviceStatusRow(state: state),
          ],
          const SizedBox(height: 12),
          // 染色歌词条：当前句逐帧染色，点击进沉浸歌词页（对齐 docs/04 窄屏布局）。
          LyricStrip(durationMs: state.durationMs),
          const SizedBox(height: 12),
          _ProgressSection(state: state, controller: controller),
          const SizedBox(height: 8),
          _ControlsSection(
            state: state,
            controller: controller,
            fallbackPlaying: fallbackPlaying,
          ),
          const SizedBox(height: 4),
          _VolumeSection(state: state, controller: controller),
        ],
      ),
    );
  }
}

// 桌面双栏（对齐 web player.js 的 .np-grid）：
// 左 .np-stage = 封面（max420 投影）+ 曲名(衬线)/歌手/状态点 + 进度 + 主控 + 音量；
// 右 .np-lyrics = 同步滚动歌词（当前行衬线放大、mask 渐隐、行点 seek）。
class _WideBody extends ConsumerWidget {
  const _WideBody({
    required this.state,
    required this.track,
    required this.controller,
    required this.fallbackPlaying,
  });

  final HMusicPlaybackState state;
  final HMusicTrack track;
  final PlayerViewModel controller;
  final bool fallbackPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 16, 48, 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 左：封面舞台。
              Expanded(
                flex: 11,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 封面吃掉剩余高度并保持正方形（cap 420）：矮窗自动收缩，
                    // 固定 420 死块在默认 720 窗高下必然竖向溢出。
                    Flexible(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: PlayerCover(track: track),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      track.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.album == null || track.album!.isEmpty
                          ? track.artist
                          : '${track.artist} · ${track.album}',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: _DeviceStatusRow(state: state)),
                    const SizedBox(height: 24),
                    _ProgressSection(state: state, controller: controller),
                    const SizedBox(height: 8),
                    _ControlsSection(
                      state: state,
                      controller: controller,
                      fallbackPlaying: fallbackPlaying,
                    ),
                    const SizedBox(height: 4),
                    _VolumeSection(state: state, controller: controller),
                  ],
                ),
              ),
              const SizedBox(width: 56),
              // 右：同步歌词栏（内容层无玻璃，行点 seek）。
              Expanded(flex: 9, child: _WideLyrics(state: state)),
            ],
          ),
        ),
      ),
    );
  }
}

// 设备状态行（B1/B2）：StateDot + 「正在播放 · 客厅音箱」，整行可点弹设备
// sheet——宽屏常驻（同 web 状态行），窄屏仅遥控模式占行（本机是默认心智）。
class _DeviceStatusRow extends StatelessWidget {
  const _DeviceStatusRow({required this.state});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => showDevicePickerSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StateDot(state.state),
            const SizedBox(width: 7),
            Text(
              _playbackStatusLabel(state),
              style: TextStyle(fontSize: 12.5, color: palette.mutedStrong),
            ),
          ],
        ),
      ),
    );
  }
}

String _playbackStatusLabel(HMusicPlaybackState state) {
  final status = switch (state.state) {
    PlaybackStatus.playing => '正在播放',
    PlaybackStatus.paused => '已暂停',
    PlaybackStatus.loading => '加载中',
    PlaybackStatus.error => '播放出错',
    _ => '未在播放',
  };
  final device = state.deviceName;
  return device == null || device.isEmpty ? status : '$status · $device';
}

// 桌面右栏歌词：复用沉浸歌词页的滚动组件，当前行按本机实时进度算。
class _WideLyrics extends ConsumerWidget {
  const _WideLyrics({required this.state});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerViewModelProvider);
    final positionMs = playbackPositionOf(ref, state).inMilliseconds;
    final activeLine = ref
        .read(lyricViewModelProvider.notifier)
        .activeLineFor(positionMs);

    return LyricScrollView(
      activeLine: activeLine,
      seekEnabled: state.seekEnabled,
      onLineTap: (timeMs) => controller.seek(Duration(milliseconds: timeMs)),
    );
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({required this.state, required this.controller});

  final HMusicPlaybackState state;
  final PlayerViewModel controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlayerProgress(
      position: playbackPositionOf(ref, state),
      duration: Duration(milliseconds: state.durationMs),
      seekEnabled: state.seekEnabled,
      onSeek: controller.seek,
    );
  }
}

class _VolumeSection extends ConsumerWidget {
  const _VolumeSection({required this.state, required this.controller});

  final HMusicPlaybackState state;
  final PlayerViewModel controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 音量行 = 音量条 + 行尾输出钮（B2，对齐 Apple Music 输出按钮的位置逻辑）。
    // 输出钮本机/遥控两种模式都在——它正是从本机切去音箱的入口。
    return Row(
      children: <Widget>[
        Expanded(child: _slider(ref)),
        IconButton(
          tooltip: '播放设备',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.speaker_group_rounded, size: 20),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          onPressed: () => showDevicePickerSheet(context),
        ),
      ],
    );
  }

  Widget _slider(WidgetRef ref) {
    // 远端设备（音箱）：调的是音箱音量（Server 0-100），拖动结束一次提交。
    // ValueKey 按设备切换重建，杜绝本机/音箱共用一份未标记的 slider 状态
    //（docs/12 §4）；非拖动时随轮询回读的真实音量同步。
    if (!state.isLocalDevice) {
      return PlayerVolumeRow(
        key: ValueKey<String>('volume-${state.deviceId}'),
        initialVolume: (state.volume / 100).clamp(0, 1).toDouble(),
        onChanged: (_) {},
        onChangeEnd: (value) =>
            controller.setDeviceVolume((value * 100).round()),
      );
    }
    // 本机：just_audio 音量（0-1），连续生效并持久化本地偏好。
    // handler 未就绪时不渲染音量条（本机播放尚未初始化），输出钮照常可用。
    final handlerAsync = ref.watch(hmusicAudioHandlerProvider);
    return handlerAsync.maybeWhen(
      data: (handler) => PlayerVolumeRow(
        key: const ValueKey<String>('volume-local'),
        initialVolume: handler.player.volume,
        onChanged: (value) => controller.setLocalVolume(value),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ControlsSection extends ConsumerWidget {
  const _ControlsSection({
    required this.state,
    required this.controller,
    required this.fallbackPlaying,
  });

  final HMusicPlaybackState state;
  final PlayerViewModel controller;
  final bool fallbackPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handlerAsync = ref.watch(hmusicAudioHandlerProvider);
    return handlerAsync.when(
      loading: () => const SizedBox(height: 72),
      error: (_, __) => const SizedBox(height: 72),
      data: (handler) => StreamBuilder<PlaybackState>(
        stream: handler.playbackState,
        builder: (context, snapshot) {
          final pbState = snapshot.data;
          final isPlaying = pbState?.playing ?? fallbackPlaying;
          final isBusy =
              pbState?.processingState == AudioProcessingState.loading ||
              pbState?.processingState == AudioProcessingState.buffering;
          return PlayerControls(
            isPlaying: isPlaying,
            isBusy: isBusy,
            mode: state.playMode,
            onPlayPause: isPlaying ? controller.pause : controller.play,
            onPrevious: controller.skipToPrevious,
            onNext: controller.skipToNext,
            onModeChanged: controller.setPlayMode,
            favorite: PlayerFavoriteButton(track: state.track),
          );
        },
      ),
    );
  }
}
