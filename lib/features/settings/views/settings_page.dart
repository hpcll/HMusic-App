import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/back_link.dart';
import '../../../shared/widgets/hmusic_toast.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/settings_section.dart';
import '../view_models/config_view_model.dart';
import '../view_models/devices_view_model.dart';
import '../view_models/diag_view_model.dart';
import '../view_models/downloads_view_model.dart';
import '../view_models/mi_account_view_model.dart';
import '../view_models/security_view_model.dart';
import '../view_models/settings_menu_view_model.dart';
import '../view_models/sources_view_model.dart';
import '../view_models/tracks_view_model.dart';
import '../widgets/sections/config_section.dart';
import '../widgets/sections/devices_section.dart';
import '../widgets/sections/diag_section.dart';
import '../widgets/sections/downloads_section.dart';
import '../widgets/sections/mi_account_section.dart';
import '../widgets/sections/security_section.dart';
import '../widgets/sections/sources_section.dart';
import '../widgets/sections/tracks_section.dart';
import '../widgets/settings_menu.dart';

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
    _listenNotices();
    final state = ref.watch(settingsMenuViewModelProvider);
    final notifier = ref.read(settingsMenuViewModelProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 860;

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
                child: SettingsMenu(
                  summary: state.summary,
                  activeSection: section,
                  onOpen: notifier.open,
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
        // 顶/底累加环境 padding：玻璃顶栏与悬浮 mini/dock 之下让位（scroll-under）。
        padding: EdgeInsets.fromLTRB(
          16,
          24 + MediaQuery.paddingOf(context).top,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          const ViewTitle('设置'),
          const SizedBox(height: 16),
          SettingsMenu(summary: state.summary, onOpen: notifier.open),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8 + MediaQuery.paddingOf(context).top,
        16,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        _SectionHead(title: section.label, onBack: () => notifier.back()),
        const SizedBox(height: 12),
        _sectionBody(section),
      ],
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
      },
    );
  }

  // 五个子页 VM 的 notice 统一在页面级转 toast（子页无各自 Scaffold）。
  // flutter_riverpod 3.x 未导出 ProviderListenable 类型，无法抽公共参数，逐个内联。
  void _listenNotices() {
    void show(HMusicNotice? notice, void Function() clearNotice) {
      if (notice == null) return;
      showHMusicToast(context, notice);
      clearNotice();
    }

    ref.listen(
      devicesViewModelProvider.select((s) => s.notice),
      (_, m) =>
          show(m, ref.read(devicesViewModelProvider.notifier).clearNotice),
    );
    ref.listen(
      configViewModelProvider.select((s) => s.notice),
      (_, m) => show(m, ref.read(configViewModelProvider.notifier).clearNotice),
    );
    ref.listen(
      diagViewModelProvider.select((s) => s.notice),
      (_, m) => show(m, ref.read(diagViewModelProvider.notifier).clearNotice),
    );
    ref.listen(
      securityViewModelProvider.select((s) => s.notice),
      (_, m) =>
          show(m, ref.read(securityViewModelProvider.notifier).clearNotice),
    );
    ref.listen(
      tracksViewModelProvider.select((s) => s.notice),
      (_, m) => show(m, ref.read(tracksViewModelProvider.notifier).clearNotice),
    );
    ref.listen(
      sourcesViewModelProvider.select((s) => s.notice),
      (_, m) =>
          show(m, ref.read(sourcesViewModelProvider.notifier).clearNotice),
    );
    ref.listen(
      downloadsViewModelProvider.select((s) => s.notice),
      (_, m) =>
          show(m, ref.read(downloadsViewModelProvider.notifier).clearNotice),
    );
    ref.listen(
      miAccountViewModelProvider.select((s) => s.notice),
      (_, m) =>
          show(m, ref.read(miAccountViewModelProvider.notifier).clearNotice),
    );
  }
}

// 窄屏子页头，对齐 web .section-head：返回键 + 居中衬线标题 + 右占位平衡。
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        BackLink(label: '设置', onTap: onBack),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'NotoSerifSC',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.palette.textStrong,
              ),
            ),
          ),
        ),
        const SizedBox(width: 64),
      ],
    );
  }
}
