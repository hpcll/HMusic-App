import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/build_edition.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../../core/playback/playback_mode_switch.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/hmusic_inline_notice.dart';
import 'playback_mode_switch_button.dart';

class PlaybackModeActions extends ConsumerWidget {
  const PlaybackModeActions({this.entry = false, super.key});
  final bool entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (BuildEdition.isStore) return const SizedBox.shrink();
    final current = ref.watch(playbackModeProvider);
    final local = ref.watch(clientPlaybackCapabilitiesProvider);
    final error = ref.watch(playbackModeSwitchProvider).error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != PlaybackMode.player && local.supportsLocalPlayback)
          PlaybackModeSwitchButton(
            mode: PlaybackMode.player,
            path: '/charts',
            label: entry ? '免登录，使用纯播放器' : '切换到纯播放器模式',
            showError: false,
          ),
        if (current != PlaybackMode.direct)
          PlaybackModeSwitchButton(
            mode: PlaybackMode.direct,
            path: '/direct/login',
            label: entry ? '无需服务器，使用直连模式' : '切换到直连模式',
            showError: false,
          ),
        if (current != PlaybackMode.server)
          const PlaybackModeSwitchButton(
            mode: PlaybackMode.server,
            path: '/connect',
            label: '切换到服务器模式',
            showError: false,
          ),
        if (error != null) HMusicInlineNotice(HMusicNotice.error(error)),
      ],
    );
  }
}
