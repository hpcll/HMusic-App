import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../models/mi_account_state.dart';
import '../../view_models/mi_account_view_model.dart';
import 'mi_import_tab.dart';
import 'mi_password_tab.dart';
import 'mi_qr_tab.dart';
import 'mi_tabs.dart';

// 小米账号子页：状态卡 + 三通道 Tabs（扫码 / 账号密码 / 导入会话）。对齐 web MiAccountSection。
// 扫码轮询/倒计时的 Timer 由 VM 持有并在 dispose 停表，本页离开时随 KeyedSubtree 重建收敛。
class MiAccountSectionView extends ConsumerStatefulWidget {
  const MiAccountSectionView({super.key});

  @override
  ConsumerState<MiAccountSectionView> createState() =>
      _MiAccountSectionViewState();
}

class _MiAccountSectionViewState extends ConsumerState<MiAccountSectionView> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(miAccountViewModelProvider.notifier).loadStatus(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(miAccountViewModelProvider);
    final notifier = ref.read(miAccountViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StatusCard(state: state, onLogout: notifier.logout),
        const SizedBox(height: 16),
        MiTabs(active: state.tab, onSelect: notifier.switchTab),
        const SizedBox(height: 16),
        switch (state.tab) {
          MiTab.qr => const MiQrTab(),
          MiTab.password => const MiPasswordTab(),
          MiTab.importSession => const MiImportTab(),
        },
      ],
    );
  }
}

// 状态卡：已登录显示掩码账号 + 青绿点 + 退出键；未登录显示 muted 点 + 提示。
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.onLogout});

  final MiAccountState state;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!state.loggedIn) {
      return HMusicCard(
        child: Row(
          children: <Widget>[
            const StateDot(PlaybackStatus.idle),
            const SizedBox(width: 8),
            Text('未登录小米账号', style: TextStyle(color: palette.text)),
          ],
        ),
      );
    }
    final masked = state.status?.accountMasked ?? '';
    return HMusicCard(
      child: Row(
        children: <Widget>[
          // 青绿点表达账号「当前在线」这件正在发生的事。
          const StateDot(PlaybackStatus.playing),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已登录 $masked'.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.text),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onLogout,
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}
