import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../view_models/player_view_model.dart';
import '../views/lyrics_page.dart';
import 'cover_swipe_area.dart';
import 'player_cover.dart';
import 'player_details_controls.dart';

// 正常竖屏尽量一屏；内容超高时自然滚动，不把 Expanded 放进无限高视口。
class PlayerStage extends ConsumerWidget {
  const PlayerStage({
    required this.state,
    this.horizontal = false,
    this.showLyricStrip = true,
    super.key,
  });

  final HMusicPlaybackState state;
  final bool horizontal;
  final bool showLyricStrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.track!;
    final controller = ref.read(playerViewModelProvider);
    Widget artwork = PlayerCover(track: track);
    if (showLyricStrip) {
      artwork = GestureDetector(
        onTap: () => context.push(LyricsPage.path),
        child: Semantics(button: true, label: '查看歌词', child: artwork),
      );
    }
    if (usesBottomNavigation(MediaQuery.sizeOf(context).width) || horizontal) {
      artwork = CoverSwipeArea(
        onNext: controller.skipToNext,
        onPrevious: controller.skipToPrevious,
        child: artwork,
      );
    }
    final details = PlayerDetailsControls(
      state: state,
      showLyricStrip: showLyricStrip,
      compact: horizontal,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal ? 16 : 24, 8, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (horizontal) {
            return Row(
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SizedBox.square(
                      dimension: math.min(280, constraints.maxHeight),
                      child: artwork,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: SingleChildScrollView(child: details)),
              ],
            );
          }
          final scaler = MediaQuery.textScalerOf(context);
          // 把文字增高优先让给控制区；估算只影响封面大小，滚动负责最终兜底。
          final controlsBudget =
              294 +
              scaler.scale(26) * 2.5 +
              scaler.scale(16) * 1.25 +
              (state.isLocalDevice && showLyricStrip
                  ? 0
                  : scaler.scale(13) * 1.25 + 20);
          final coverSize = math.min(
            math.min(420.0, constraints.maxWidth),
            math.max(112.0, constraints.maxHeight - controlsBudget),
          );
          return SingleChildScrollView(
            child: Column(
              children: <Widget>[
                SizedBox.square(dimension: coverSize, child: artwork),
                const SizedBox(height: 20),
                details,
              ],
            ),
          );
        },
      ),
    );
  }
}
