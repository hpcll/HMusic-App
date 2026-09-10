import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../app/theme/hmusic_radii.dart';
import '../../../core/app_version.dart';
import '../models/settings_section.dart';
import '../models/settings_summary.dart';
import 'settings_menu_row.dart';

// 两种模式共用分组与摘要，大字模式下摘要自然排到标签下方。
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({
    required this.summary,
    required this.onOpen,
    this.activeSection,
    this.updateAvailable = false,
    this.direct = false,
    super.key,
  });
  final SettingsSummary summary;
  final ValueChanged<SettingsSection> onOpen;
  final SettingsSection? activeSection;
  final bool updateAvailable, direct;

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final group in _groups)
        (
          group.$1,
          group.$2.where((item) => !direct || item.$1.availableDirect).toList(),
        ),
    ].where((group) => group.$2.isNotEmpty).toList();
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, group) in groups.indexed) ...[
          if (index > 0) const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 9),
            child: Text(
              direct && group.$1 == '播放与诊断' ? '播放偏好' : group.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette.muted,
              ),
            ),
          ),
          Material(
            color: palette.panel,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HMusicRadii.card),
              side: BorderSide(color: palette.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (row, item) in group.$2.indexed) ...[
                  if (row > 0)
                    Divider(height: 1, indent: 60, color: palette.lineSoft),
                  SettingsMenuRow(
                    icon: item.$2,
                    label: item.$1.title(direct: direct),
                    summary: _summaryFor(item.$1),
                    active: activeSection == item.$1,
                    badged: updateAvailable && item.$1 == SettingsSection.about,
                    onTap: () => onOpen(item.$1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _summaryFor(SettingsSection section) => switch (section) {
    SettingsSection.mi => summary.mi,
    SettingsSection.devices => summary.devices,
    SettingsSection.sources => summary.sources,
    SettingsSection.downloads => summary.downloads,
    SettingsSection.tracks => summary.tracks,
    SettingsSection.config => summary.config,
    SettingsSection.diag => '播放状态与连接测试',
    SettingsSection.security => '管理服务器登录密码',
    SettingsSection.about => 'v$kAppVersion',
  };
}

const _groups = <(String, List<(SettingsSection, IconData)>)>[
  (
    '账号与设备',
    [
      (SettingsSection.mi, Icons.person_outline_rounded),
      (SettingsSection.devices, Icons.speaker_outlined),
    ],
  ),
  (
    '音源与内容',
    [
      (SettingsSection.sources, Icons.extension_outlined),
      (SettingsSection.downloads, Icons.download_outlined),
      (SettingsSection.tracks, Icons.library_music_outlined),
    ],
  ),
  (
    '播放与诊断',
    [
      (SettingsSection.config, Icons.tune_rounded),
      (SettingsSection.diag, Icons.monitor_heart_outlined),
    ],
  ),
  ('安全', [(SettingsSection.security, Icons.lock_outline_rounded)]),
  ('关于', [(SettingsSection.about, Icons.info_outline_rounded)]),
];
