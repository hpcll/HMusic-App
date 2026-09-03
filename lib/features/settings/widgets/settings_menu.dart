import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../app/theme/hmusic_radii.dart';
import '../../../core/app_version.dart';
import '../models/settings_section.dart';
import '../models/settings_summary.dart';

// 设置菜单，对齐 web .settings-menu：四个分组卡，每行 图标+标签+实时摘要+chevron。
// activeSection 仅桌面双栏传入（active 行墨底反白）；窄屏传 null。
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({
    required this.summary,
    required this.onOpen,
    this.activeSection,
    this.updateAvailable = false,
    super.key,
  });

  final SettingsSummary summary;
  final ValueChanged<SettingsSection> onOpen;
  final SettingsSection? activeSection;

  // 有新版可下：「关于与更新」行点一个红点（进 App 静默检出来的，见
  // core/upgrade/app_update_badge.dart）。
  final bool updateAvailable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < _kGroups.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 18),
          _MenuGroup(
            spec: _kGroups[i],
            summary: summary,
            activeSection: activeSection,
            updateAvailable: updateAvailable,
            onOpen: onOpen,
          ),
        ],
      ],
    );
  }
}

class _MenuGroupSpec {
  const _MenuGroupSpec(this.title, this.items);

  final String title;
  final List<_MenuItemSpec> items;
}

class _MenuItemSpec {
  const _MenuItemSpec(this.section, this.icon);

  final SettingsSection section;
  final IconData icon;
}

const List<_MenuGroupSpec> _kGroups = <_MenuGroupSpec>[
  _MenuGroupSpec('账号与设备', <_MenuItemSpec>[
    _MenuItemSpec(SettingsSection.mi, Icons.person_outline_rounded),
    _MenuItemSpec(SettingsSection.devices, Icons.speaker_outlined),
  ]),
  _MenuGroupSpec('音源与内容', <_MenuItemSpec>[
    _MenuItemSpec(SettingsSection.sources, Icons.extension_outlined),
    _MenuItemSpec(SettingsSection.downloads, Icons.download_outlined),
    _MenuItemSpec(SettingsSection.tracks, Icons.description_outlined),
  ]),
  _MenuGroupSpec('播放与诊断', <_MenuItemSpec>[
    _MenuItemSpec(SettingsSection.config, Icons.tune_rounded),
    _MenuItemSpec(SettingsSection.diag, Icons.monitor_heart_outlined),
  ]),
  _MenuGroupSpec('安全', <_MenuItemSpec>[
    _MenuItemSpec(SettingsSection.security, Icons.lock_outline_rounded),
  ]),
  _MenuGroupSpec('关于', <_MenuItemSpec>[
    _MenuItemSpec(SettingsSection.about, Icons.system_update_alt_rounded),
  ]),
];

String _summaryFor(SettingsSummary summary, SettingsSection section) {
  return switch (section) {
    SettingsSection.mi => summary.mi,
    SettingsSection.devices => summary.devices,
    SettingsSection.sources => summary.sources,
    SettingsSection.downloads => summary.downloads,
    SettingsSection.tracks => summary.tracks,
    SettingsSection.config => summary.config,
    SettingsSection.about => 'v$kAppVersion',
    _ => '',
  };
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.spec,
    required this.summary,
    required this.activeSection,
    required this.updateAvailable,
    required this.onOpen,
  });

  final _MenuGroupSpec spec;
  final SettingsSummary summary;
  final SettingsSection? activeSection;
  final bool updateAvailable;
  final ValueChanged<SettingsSection> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 4),
          child: Text(
            spec.title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.88,
              color: palette.muted,
            ),
          ),
        ),
        // 菜单卡：.menu-card padding 0，行间 line-soft 分隔。
        Material(
          color: palette.panel,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HMusicRadii.card),
            side: BorderSide(color: palette.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < spec.items.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: palette.lineSoft),
                _MenuRow(
                  spec: spec.items[i],
                  summaryText: _summaryFor(summary, spec.items[i].section),
                  active: activeSection == spec.items[i].section,
                  badged:
                      updateAvailable &&
                      spec.items[i].section == SettingsSection.about,
                  onTap: () => onOpen(spec.items[i].section),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.spec,
    required this.summaryText,
    required this.active,
    required this.badged,
    required this.onTap,
  });

  final _MenuItemSpec spec;
  final String summaryText;
  final bool active;

  // 「关于与更新」行的新版红点。
  final bool badged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // active（桌面双栏）：墨底反白，摘要/图标随之淡化（对齐 .menu-row.active）。
    final fore = active ? palette.background : palette.text;
    final soft = active
        ? palette.background.withValues(alpha: 0.75)
        : palette.muted;
    return Material(
      color: active ? palette.textStrong : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: <Widget>[
              Icon(
                spec.icon,
                size: 17,
                color: active ? soft : palette.mutedStrong,
              ),
              const SizedBox(width: 11),
              Text(
                spec.section.label,
                style: TextStyle(fontSize: 14, color: fore),
              ),
              if (badged) ...<Widget>[const SizedBox(width: 6), _UpdateDot()],
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  summaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: soft),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 16, color: soft),
            ],
          ),
        ),
      ),
    );
  }
}

// 新版红点：设置入口的唯一提示形态（不弹窗、不横幅——用户明确要求只在设置页
// 提示）。红色取主题 error，与「危险操作」同一支色，读作「有事待办」。
class _UpdateDot extends StatelessWidget {
  const _UpdateDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}
