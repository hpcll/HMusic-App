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

// 小米账号子页：状态卡 + 三通道（扫码 / 账号密码 / 导入会话）。
// 已登录默认只留状态卡，三通道收进「更换账号」（Server 单账号：再登录是替换）；
// 未登录直接展开三通道。web 登录后仍常驻 Tabs，此处刻意偏离（铁律 2 允许）。
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
        _StatusCard(
          state: state,
          onLogout: notifier.logout,
          onToggleChange: notifier.toggleChangeAccount,
        ),
        // 面板开合走 mini player 同款节奏（docs/03 §4：220ms easeOut 高度过渡）。
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: state.showLoginPanel
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    if (state.loggedIn) ...<Widget>[
                      // 替换语义必须先讲清楚，用户才不会误以为在「新增」。
                      Text(
                        '登录新账号后将替换当前账号。',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.palette.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    MiTabs(active: state.tab, onSelect: notifier.switchTab),
                    const SizedBox(height: 16),
                    switch (state.tab) {
                      MiTab.qr => const MiQrTab(),
                      MiTab.password => const MiPasswordTab(),
                      MiTab.importSession => const MiImportTab(),
                    },
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// 状态卡：已登录显示掩码账号 + 青绿点 + 更换/退出键；未登录显示 muted 点 + 提示。
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.onLogout,
    required this.onToggleChange,
  });

  final MiAccountState state;
  final VoidCallback onLogout;
  final VoidCallback onToggleChange;

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
          // 更换是低危动作放常规灰字；退出是破坏动作保持 danger。
          TextButton(
            onPressed: onToggleChange,
            style: TextButton.styleFrom(foregroundColor: palette.mutedStrong),
            child: Text(state.changingAccount ? '取消更换' : '更换账号'),
          ),
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
