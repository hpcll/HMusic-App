import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/build_edition.dart';
import '../../core/playback/playback_mode.dart';
import '../../core/playback/playback_mode_controller.dart';
import '../../features/connection/widgets/playback_mode_switch_button.dart';
import '../../features/settings/views/settings_page.dart';
import 'direct_settings_page.dart';

class PlaybackSettingsPage extends ConsumerWidget {
  const PlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(playbackModeProvider) == PlaybackMode.direct) {
      return const DirectSettingsPage();
    }
    return SettingsPage(
      modeSwitch: BuildEdition.isStore
          ? null
          : const PlaybackModeSwitchButton(
              mode: PlaybackMode.direct,
              path: '/direct/login',
              label: '切换到直连模式',
            ),
    );
  }
}
