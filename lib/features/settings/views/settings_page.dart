import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/upgrade/app_update_badge.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/settings_section.dart';
import '../view_models/settings_menu_view_model.dart';
import '../widgets/account_card.dart';
import '../widgets/sections/about_section.dart';
import '../widgets/sections/config_section.dart';
import '../widgets/sections/devices_section.dart';
import '../widgets/sections/diag_section.dart';
import '../widgets/sections/downloads_section.dart';
import '../widgets/sections/mi_account_section.dart';
import '../widgets/sections/security_section.dart';
import '../widgets/sections/sources_section.dart';
import '../widgets/sections/tracks_section.dart';
import '../widgets/server_switch_row.dart';
import '../widgets/settings_menu.dart';
import '../widgets/settings_section_subpage.dart';

// 设置中心，对齐 web settings.js：
// 桌面（≥860）双栏——左菜单常驻 + 右内容，section 恒有值（空则回退第一项）；
// 窄屏两级——菜单页 ↔ 子页，返回时刷新菜单摘要。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const String path = '/settings';

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(settingsMenuViewModelProvider.notifier).loadSummary(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsMenuViewModelProvider);
    final notifier = ref.read(settingsMenuViewModelProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 860;
    // 有新版 = 「关于与更新」行点红点（唯一的更新提示位，见 app_update_badge）。
    ref.watch(appUpdateBadgeProvider);
    final updateAvailable = ref.read(appUpdateBadgeProvider.notifier).hasUpdate;

    if (wide) {
      final section = state.section ?? SettingsSection.mi;
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          24 + MediaQuery.paddingOf(context).top,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          const ViewTitle('设置'),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SettingsMenu(
                      summary: state.summary,
                      activeSection: section,
                      updateAvailable: updateAvailable,
                      onOpen: notifier.open,
                    ),
                    // 桌面「更换服务器」入口挂菜单列底部（退出走侧栏，不在此重复）。
                    const SettingsServerSwitchRow(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      section.label,
                      style: TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionBody(section),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    final section = state.section;
    if (section == null) {
      return ListView(
        // 顶/底累加环境 padding：顶部消融带与悬浮 mini/dock 之下让位（scroll-under）。
        padding: EdgeInsets.fromLTRB(
          16,
          24 + MediaQuery.paddingOf(context).top,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          const ViewTitle('设置'),
          const SizedBox(height: 16),
          SettingsMenu(
            summary: state.summary,
            updateAvailable: updateAvailable,
            onOpen: notifier.open,
          ),
          // 窄屏账户操作卡片（桌面走侧栏，不渲染）：当前服务器 + 更换服务器（次要）
          // + 退出登录（危险操作红色 outlined）——账户区块化，信息层级清晰。
          const SettingsAccountCard(),
        ],
      );
    }
    return SettingsSectionSubpage(
      title: section.label,
      onBack: () => notifier.back(),
      child: _sectionBody(section),
    );
  }

  // KeyedSubtree：桌面切换子页时强制重建，保证 initState 加载/轮询生命周期正确。
  Widget _sectionBody(SettingsSection section) {
    return KeyedSubtree(
      key: ValueKey<SettingsSection>(section),
      child: switch (section) {
        SettingsSection.mi => const MiAccountSectionView(),
        SettingsSection.devices => const DevicesSectionView(),
        SettingsSection.sources => const SourcesSectionView(),
        SettingsSection.downloads => const DownloadsSectionView(),
        SettingsSection.config => const ConfigSectionView(),
        SettingsSection.diag => const DiagSectionView(),
        SettingsSection.security => const SecuritySectionView(),
        SettingsSection.tracks => const TracksSectionView(),
        SettingsSection.about => const AboutSectionView(),
      },
    );
  }
}
