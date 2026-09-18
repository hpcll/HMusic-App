import 'package:flutter/material.dart';

import '../../features/connection/widgets/playback_mode_actions.dart';
import '../../features/settings/models/settings_section.dart';
import '../../features/settings/views/settings_page.dart';

// 本地模式共用设置框架，纯播放器只展示本机音源与播放偏好。
class DirectSettingsPage extends StatelessWidget {
  const DirectSettingsPage({
    this.localOnly = false,
    this.initialSection,
    super.key,
  });
  final bool localOnly;
  final SettingsSection? initialSection;

  @override
  Widget build(BuildContext context) => SettingsPage(
    direct: true,
    localOnly: localOnly,
    initialSection: initialSection,
    modeSwitch: const PlaybackModeActions(),
  );
}
