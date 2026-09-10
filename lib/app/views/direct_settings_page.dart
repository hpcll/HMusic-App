import 'package:flutter/material.dart';

import '../../core/playback/playback_mode.dart';
import '../../features/connection/widgets/playback_mode_switch_button.dart';
import '../../features/settings/views/settings_page.dart';

// 两种模式共用设置框架，只在装配层提供适用入口。
class DirectSettingsPage extends StatelessWidget {
  const DirectSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const SettingsPage(
    direct: true,
    modeSwitch: PlaybackModeSwitchButton(
      mode: PlaybackMode.server,
      path: '/connect',
      label: '切换到服务器模式',
    ),
  );
}
