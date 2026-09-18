import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/playback/playback_mode.dart';
import '../../core/playback/playback_mode_controller.dart';
import '../../features/connection/widgets/playback_mode_actions.dart';
import '../../features/settings/models/settings_section.dart';
import '../../features/settings/views/settings_page.dart';
import 'direct_settings_page.dart';

class PlaybackSettingsPage extends ConsumerWidget {
  const PlaybackSettingsPage({this.initialSection, super.key});
  final SettingsSection? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(playbackModeProvider);
    if (mode.usesLocalBackend) {
      return DirectSettingsPage(
        key: ValueKey((mode, initialSection)),
        localOnly: mode == PlaybackMode.player,
        initialSection: initialSection,
      );
    }
    return SettingsPage(
      initialSection: initialSection,
      modeSwitch: const PlaybackModeActions(),
    );
  }
}
