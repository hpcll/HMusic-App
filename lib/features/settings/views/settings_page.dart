import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/upgrade/app_update_badge.dart';
import '../../../shared/layout/shell_metrics.dart';
import '../models/settings_section.dart';
import '../view_models/settings_menu_view_model.dart';
import '../widgets/account_card.dart';
import '../widgets/sections/about_section.dart';
import '../widgets/sections/config_section.dart';
import '../widgets/sections/devices_section.dart';
import '../widgets/sections/diag_section.dart';
import '../widgets/sections/direct_account_section.dart';
import '../widgets/sections/direct_options_section.dart';
import '../widgets/sections/downloads_section.dart';
import '../widgets/sections/mi_account_section.dart';
import '../widgets/sections/security_section.dart';
import '../widgets/sections/sources_section.dart';
import '../widgets/sections/tracks_section.dart';
import '../widgets/server_switch_row.dart';
import '../widgets/settings_menu.dart';
import '../widgets/settings_overview.dart';
import '../widgets/settings_section_subpage.dart';
import '../widgets/settings_wide_layout.dart';

// 设置中心，对齐 web settings.js：
// 内容容得下菜单与正文时双栏；窄内容区复用菜单/子页，不按整个窗口宽度硬切。
// 窄屏两级——菜单页 ↔ 子页，返回时刷新菜单摘要。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.modeSwitch, this.direct = false});

  final Widget? modeSwitch;
  final bool direct;

  static const String path = '/settings';

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // 布局切换时迁移同一子页实例，保留尚未提交的表单输入；切 section 仍按值 key 重建。
  final GlobalKey _sectionContentKey = GlobalKey();
  bool _wideLayout = false;

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
    // 有新版 = 「关于与更新」行点红点（唯一的更新提示位，见 app_update_badge）。
    ref.watch(appUpdateBadgeProvider);
    final updateAvailable = ref.read(appUpdateBadgeProvider.notifier).hasUpdate;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 菜单随文字放大增宽；两侧 16、间距 32，正文仍至少 480。
        final scaler = MediaQuery.textScalerOf(context);
        final menuWidth = 240.0 * math.max(1.0, scaler.scale(14) / 14);
        final wide = constraints.maxWidth >= menuWidth + 32 + 480 + 32;
        _wideLayout = wide;
        if (wide && state.section == null) _rememberDefaultSection();
        final selectedSection = state.section ?? SettingsSection.mi;
        final menu = SettingsMenu(
          direct: widget.direct,
          summary: state.summary,
          activeSection: wide ? selectedSection : null,
          updateAvailable: updateAvailable,
          onOpen: notifier.open,
        );
        if (wide) {
          return SettingsWideLayout(
            direct: widget.direct,
            menuWidth: menuWidth,
            menu: menu,
            menuFooter: _footer(context),
            sectionTitle: selectedSection.title(direct: widget.direct),
            child: _sectionBody(selectedSection),
          );
        }

        final section = state.section;
        if (section == null) return _menuPage(context, menu);
        return SettingsSectionSubpage(
          title: section.title(direct: widget.direct),
          onBack: () => notifier.back(),
          child: _sectionBody(section),
        );
      },
    );
  }

  // 默认面板也记录成已选项，缩窄时才能继续迁移同一表单；首帧完成后再更新 VM。
  void _rememberDefaultSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_wideLayout ||
          ref.read(settingsMenuViewModelProvider).section != null) {
        return;
      }
      ref.read(settingsMenuViewModelProvider.notifier).open(SettingsSection.mi);
    });
  }

  Widget _menuPage(BuildContext context, Widget menu) => ListView(
    // 顶/底累加环境 padding：为顶部消融带与悬浮 mini/dock 让位。
    padding: EdgeInsets.fromLTRB(
      16,
      24 + MediaQuery.paddingOf(context).top,
      16,
      32 + MediaQuery.paddingOf(context).bottom,
    ),
    children: <Widget>[
      SettingsOverview(direct: widget.direct),
      const SizedBox(height: 24),
      menu,
      _footer(context),
    ],
  );

  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.modeSwitch != null) widget.modeSwitch!,
        if (!widget.direct)
          if (usesBottomNavigation(MediaQuery.sizeOf(context).width))
            const SettingsAccountCard()
          else
            const SettingsServerSwitchRow(),
      ],
    ),
  );

  // KeyedSubtree：桌面切换子页时强制重建，保证 initState 加载/轮询生命周期正确。
  Widget _sectionBody(SettingsSection section) {
    return KeyedSubtree(
      key: _sectionContentKey,
      child: KeyedSubtree(
        key: ValueKey<SettingsSection>(section),
        child: switch (section) {
          SettingsSection.mi =>
            widget.direct
                ? const DirectAccountSection()
                : const MiAccountSectionView(),
          SettingsSection.devices => const DevicesSectionView(),
          SettingsSection.sources => const SourcesSectionView(),
          SettingsSection.downloads => const DownloadsSectionView(),
          SettingsSection.config =>
            widget.direct
                ? const DirectOptionsSection()
                : const ConfigSectionView(),
          SettingsSection.diag => const DiagSectionView(),
          SettingsSection.security => const SecuritySectionView(),
          SettingsSection.tracks => const TracksSectionView(),
          SettingsSection.about => const AboutSectionView(),
        },
      ),
    );
  }
}
